import io
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import threading
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import chrome_tab as bridge


class ProtocolTests(unittest.TestCase):
    def test_utf8_native_roundtrip(self):
        stream = io.BytesIO()
        bridge.write_native(stream, {"text": "héllo 世界"})
        stream.seek(0)
        self.assertEqual(bridge.read_native(stream), {"text": "héllo 世界"})

    def test_partial_reads(self):
        class PartialReader(io.BytesIO):
            def read(self, size):
                return super().read(min(2, size))
        payload = b'{"x":1}'
        self.assertEqual(bridge.read_native(PartialReader(struct.pack("=I", len(payload)) + payload)), {"x": 1})

    def test_rejects_invalid_frames(self):
        for data in (b"", b"\x01", struct.pack("=I", bridge.MAX_MESSAGE + 1), struct.pack("=I", 0)):
            with self.subTest(data=data), self.assertRaises((EOFError, ValueError)):
                bridge.read_native(io.BytesIO(data))

    def test_rejects_large_output_and_unterminated_lines(self):
        with self.assertRaises(ValueError):
            bridge.encode({"value": "x" * bridge.MAX_MESSAGE})
        with self.assertRaises(ValueError):
            bridge.read_line(io.BytesIO(b'{}'))

    def test_rejects_unsafe_socket_directory(self):
        for mode, uid in ((0o40755, os.getuid()), (0o120700, os.getuid()), (0o40700, os.getuid() + 1)):
            info = os.stat_result((mode, 0, 0, 1, uid, 0, 0, 0, 0, 0))
            with patch.object(Path, "mkdir"), patch.object(Path, "lstat", return_value=info):
                with self.assertRaisesRegex(ValueError, "Unsafe"):
                    bridge.socket_directory()


class HostTests(unittest.TestCase):
    def setUp(self):
        self.process = subprocess.Popen(
            [sys.executable, "-B", bridge.__file__, "native-host", "chrome-extension://" + "a" * 32 + "/"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.endpoint = bridge.socket_directory() / f"{self.process.pid}.sock"
        deadline = time.monotonic() + 5
        while not self.endpoint.exists():
            if self.process.poll() is not None:
                self.fail(self.process.stderr.read().decode())
            if time.monotonic() > deadline:
                self.fail("Host did not create its socket")
            time.sleep(0.01)

    def tearDown(self):
        if not self.process.stdin.closed:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.process.stdout.close()
        self.process.stderr.close()
        self.endpoint.unlink(missing_ok=True)

    def cli(self, *args, input_text=None):
        return subprocess.run(
            [sys.executable, "-B", bridge.__file__, "--session", str(self.process.pid), *args],
            input=input_text, capture_output=True, text=True, timeout=10,
        )

    def emulate_chrome(self, reply):
        received = []
        def respond():
            message = bridge.read_native(self.process.stdout)
            received.append(message)
            bridge.write_native(self.process.stdin, {"id": message["id"], **reply})
        thread = threading.Thread(target=respond, daemon=True)
        thread.start()
        return thread, received

    def test_cli_eval_stdin_and_error_exit(self):
        thread, received = self.emulate_chrome({"result": {"type": "number", "value": 42}})
        completed = self.cli("eval", "123", "-", input_text="Promise.resolve(42)")
        thread.join(5)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["value"], 42)
        self.assertEqual(received[0]["expression"], "Promise.resolve(42)")
        self.assertEqual(received[0]["tabId"], 123)
        thread, _ = self.emulate_chrome({"error": "Tab is not connected"})
        completed = self.cli("eval", "456", "document.title")
        thread.join(5)
        self.assertEqual(completed.returncode, 1)
        self.assertIn("Tab is not connected", completed.stderr)

    def test_cli_tabs_session_and_socket_permissions(self):
        self.assertEqual(self.endpoint.stat().st_mode & 0o777, 0o600)
        thread, _ = self.emulate_chrome({"result": [{"tabId": 123, "title": "Example", "url": "https://example.test"}]})
        completed = self.cli("tabs")
        thread.join(5)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(json.loads(completed.stdout)[0]["session"], str(self.process.pid))

    def test_rejects_unknown_method_without_forwarding(self):
        with self.assertRaisesRegex(ValueError, "Unknown method"):
            bridge.request(self.endpoint, {"method": "attach", "tabId": 123})

    def test_native_eof_removes_socket(self):
        self.process.stdin.close()
        self.process.wait(timeout=5)
        self.assertFalse(self.endpoint.exists())

    def test_concurrent_requests_fail_without_queuing(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(str(self.endpoint))
            client.sendall(b'{"method":"eval","tabId":123,"expression":"slow()"}\n')
            message = bridge.read_native(self.process.stdout)
            with self.assertRaisesRegex(ValueError, "busy"):
                bridge.request(self.endpoint, {"method": "eval", "tabId": 123, "expression": "mutation()"})
            # A late response from an earlier timed-out request is never reused.
            bridge.write_native(self.process.stdin, {"id": "old-request", "result": "wrong"})
            bridge.write_native(self.process.stdin, {"id": message["id"], "result": "correct"})
            with client.makefile("rb") as stream:
                self.assertEqual(bridge.read_line(stream)["result"], "correct")

    def test_inflight_request_fails_when_chrome_disconnects(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(str(self.endpoint))
            client.sendall(b'{"method":"tabs"}\n')
            bridge.read_native(self.process.stdout)
            self.process.stdin.close()
            with client.makefile("rb") as stream:
                self.assertEqual(bridge.read_line(stream)["error"], "Chrome disconnected")


if __name__ == "__main__":
    unittest.main()
