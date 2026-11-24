import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import aurora_control  # noqa: E402
import viewer_api  # noqa: E402
from fake_viewer import FakeViewer, echo  # noqa: E402


class RequestTests(unittest.TestCase):
    def setUp(self):
        self.viewer = FakeViewer(echo)
        self.addCleanup(self.viewer.close)

    def test_a_request_is_one_line_with_its_id_tool_and_arguments(self):
        answer = viewer_api.request(self.viewer.directory, "viewer_query", {"topic": "chat"}, request_id="r1")
        self.assertEqual(answer, {"request_id": "r1", "result": {"tool": "viewer_query", "arguments": {"topic": "chat"}}})
        self.assertEqual(self.viewer.requests, [{"request_id": "r1", "tool": "viewer_query", "arguments": {"topic": "chat"}}])

    def test_an_id_is_generated_and_kept(self):
        answer = viewer_api.request(self.viewer.directory, "viewer_state")
        self.assertEqual(len(answer["request_id"]), 36)
        self.assertEqual(answer["request_id"], self.viewer.requests[0]["request_id"])

    def test_call_raises_with_the_request_id(self):
        with self.assertRaises(viewer_api.ViewerError) as caught:
            viewer_api.call(self.viewer.directory, "viewer_chat", op="say", text="hi")
        self.assertEqual(caught.exception.error["code"], "refused")
        self.assertEqual(caught.exception.request_id, self.viewer.requests[0]["request_id"])
        self.assertEqual(viewer_api.call(self.viewer.directory, "viewer_state"), {"tool": "viewer_state", "arguments": {}})

    def test_invalid_arguments_are_refused_before_sending(self):
        with self.assertRaises(ValueError):
            viewer_api.request(self.viewer.directory, "viewer_state", ["not", "an", "object"])
        self.assertEqual(self.viewer.requests, [])


class FailureTests(unittest.TestCase):
    def test_no_endpoint_means_nothing_was_sent(self):
        with self.assertRaises(viewer_api.ViewerUnavailable):
            viewer_api.request("/tmp/acf-no-such-viewer", "viewer_state")

    def check_lost(self, handler, code):
        viewer = FakeViewer(handler)
        self.addCleanup(viewer.close)
        answer = viewer_api.request(viewer.directory, "viewer_move", {"op": "stop"}, request_id="lost-1", timeout=0.5)
        self.assertEqual(answer["request_id"], "lost-1")
        self.assertEqual(answer["error"]["code"], code)
        self.assertIn("viewer_events", answer["error"]["message"])

    def test_a_closed_connection_keeps_the_request_id(self):
        self.check_lost(lambda request: None, "disconnected")

    def test_a_reply_that_is_not_json_is_a_protocol_error(self):
        self.check_lost(lambda request: b"nope\n", "protocol")

    def test_a_reply_without_result_or_error_is_a_protocol_error(self):
        self.check_lost(lambda request: {"request_id": "lost-1"}, "protocol")

    def test_a_silent_viewer_times_out(self):
        self.check_lost(lambda request: b"", "timeout")

    def test_a_reply_split_across_reads_is_joined(self):
        big = "x" * 300_000
        viewer = FakeViewer(lambda request: {"request_id": request["request_id"], "result": big})
        self.addCleanup(viewer.close)
        self.assertEqual(viewer_api.request(viewer.directory, "viewer_capture", {"op": "poll"})["result"], big)


class CliTests(unittest.TestCase):
    def setUp(self):
        self.viewer = FakeViewer(echo)
        self.addCleanup(self.viewer.close)

    def run_cli(self, argv, stdin):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("sys.stdin", io.StringIO(stdin)), redirect_stdout(out), redirect_stderr(err):
            status = aurora_control.main(argv)
        return status, out.getvalue(), err.getvalue()

    def test_arguments_come_from_stdin(self):
        status, out, _ = self.run_cli(["--directory", str(self.viewer.directory), "viewer_query"], '{"topic": "chat"}\n')
        self.assertEqual(status, 0)
        self.assertEqual(json.loads(out)["result"]["arguments"], {"topic": "chat"})

    def test_empty_stdin_is_an_empty_object(self):
        status, out, _ = self.run_cli(["--directory", str(self.viewer.directory), "--request-id", "c1", "viewer_state"], "")
        self.assertEqual((status, json.loads(out)["request_id"]), (0, "c1"))

    def test_an_error_reply_exits_1(self):
        status, out, _ = self.run_cli(["--directory", str(self.viewer.directory), "viewer_chat"], '{"op": "say", "text": "x"}')
        self.assertEqual(status, 1)
        self.assertEqual(json.loads(out)["error"]["code"], "refused")

    def test_bad_input_and_no_viewer_exit_2(self):
        self.assertEqual(self.run_cli(["--directory", str(self.viewer.directory), "viewer_state"], "[1]")[0], 2)
        self.assertEqual(self.run_cli(["--directory", str(self.viewer.directory), "viewer_state"], "{")[0], 2)
        status, _, err = self.run_cli(["--directory", "/tmp/acf-none", "viewer_state"], "{}")
        self.assertEqual(status, 2)
        self.assertIn("AURORA_CONTROL_DIR", err)


if __name__ == "__main__":
    unittest.main()
