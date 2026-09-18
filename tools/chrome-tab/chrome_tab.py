#!/usr/bin/env python3
"""Local CLI and Chrome native messaging host; Python standard library only."""

import argparse
import json
import os
from pathlib import Path
import queue
import socket
import socketserver
import stat
import struct
import sys
import threading
import time
import uuid

MAX_MESSAGE = 900_000
TIMEOUT = 35


def socket_directory():
    # Short enough for macOS's Unix socket path limit; private to this OS user.
    directory = Path(f"/tmp/forge-chrome-tab-{os.getuid()}")
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid()
            or stat.S_IMODE(info.st_mode) != 0o700):
        raise ValueError(f"Unsafe socket directory: {directory}")
    return directory


def encode(message):
    data = json.dumps(message, allow_nan=False, separators=(",", ":")).encode()
    if len(data) > MAX_MESSAGE:
        raise ValueError("Message exceeds 900 KB")
    return data


def read_exact(stream, size):
    data = bytearray()
    while len(data) < size:
        part = stream.read(size - len(data))
        if not part:
            raise EOFError("Native messaging pipe closed")
        data.extend(part)
    return bytes(data)


def read_native(stream):
    size, = struct.unpack("=I", read_exact(stream, 4))
    if not 0 < size <= MAX_MESSAGE:
        raise ValueError("Invalid native message size")
    return json.loads(read_exact(stream, size))


def write_native(stream, message):
    data = encode(message)
    stream.write(struct.pack("=I", len(data)) + data)
    stream.flush()


def read_line(stream):
    data = stream.readline(MAX_MESSAGE + 1)
    if len(data) > MAX_MESSAGE or not data.endswith(b"\n"):
        raise ValueError("Expected a JSON line smaller than 900 KB")
    return json.loads(data)


def native_host():
    responses = queue.Queue()
    stopped = threading.Event()
    request_lock = threading.Lock()

    def read_responses():
        try:
            while True:
                responses.put(read_native(sys.stdin.buffer))
        except (EOFError, ValueError, OSError) as error:
            print(str(error), file=sys.stderr)
        finally:
            stopped.set()
            responses.put(None)

    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            self.connection.settimeout(TIMEOUT + 5)
            try:
                request = read_line(self.rfile)
                if not isinstance(request, dict):
                    raise ValueError("Expected a JSON object")
                if request.get("method") not in ("tabs", "eval", "detach"):
                    raise ValueError("Unknown method")
                # Reject concurrent work instead of queuing mutations that might
                # execute after their caller has already timed out.
                if not request_lock.acquire(blocking=False):
                    raise ValueError("Bridge is busy with another request")
                try:
                    if stopped.is_set():
                        raise ValueError("Chrome disconnected")
                    request["id"] = uuid.uuid4().hex
                    write_native(sys.stdout.buffer, request)
                    deadline = time.monotonic() + TIMEOUT
                    while True:
                        response = responses.get(timeout=max(0, deadline - time.monotonic()))
                        if response is None:
                            raise ValueError("Chrome disconnected")
                        if isinstance(response, dict) and response.get("id") == request["id"]:
                            break
                finally:
                    request_lock.release()
                self.wfile.write(encode(response) + b"\n")
            except (ValueError, OSError, queue.Empty) as error:
                message = str(error) or "Evaluation timed out; it may still be running in Chrome"
                try:
                    self.wfile.write(encode({"error": message}) + b"\n")
                except OSError:
                    pass

    class Server(socketserver.ThreadingUnixStreamServer):
        daemon_threads = True

    socket_path = socket_directory() / f"{os.getpid()}.sock"
    # Never unlink another process's endpoint, including one left by a reused PID.
    with Server(str(socket_path), Handler) as server:
        os.chmod(socket_path, 0o600)
        server.timeout = 0.5
        threading.Thread(target=read_responses, daemon=True).start()
        try:
            while not stopped.is_set():
                server.handle_request()
        finally:
            socket_path.unlink(missing_ok=True)


def request(socket_path, message):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(TIMEOUT + 5)
        client.connect(str(socket_path))
        client.sendall(encode(message) + b"\n")
        with client.makefile("rb") as stream:
            response = read_line(stream)
    if not isinstance(response, dict):
        raise ValueError("Invalid bridge response")
    if "error" in response:
        raise ValueError(response["error"])
    return response["result"]


def sessions(directory):
    live = []
    for socket_path in sorted(directory.glob("*.sock")):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1)
            try:
                client.connect(str(socket_path))
            except (ConnectionRefusedError, FileNotFoundError):
                continue
        live.append(socket_path)
    return live


def main():
    parser = argparse.ArgumentParser(prog="chrome-tab", description=__doc__)
    parser.add_argument("--session", help="Browser bridge session from the tabs output")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("tabs", help="List explicitly connected tabs in all browser sessions")
    evaluate = commands.add_parser("eval", help="Evaluate an expression in the tab's main frame")
    evaluate.add_argument("tab_id", type=int)
    evaluate.add_argument("expression", help="JavaScript expression, or - to read stdin")
    detach = commands.add_parser("detach", help="Disconnect a tab")
    detach.add_argument("tab_id", type=int)
    host_parser = commands.add_parser("native-host", help="Chrome native messaging entry point")
    # Chrome supplies its extension origin as the first native-host argument.
    host_parser.add_argument("origin", nargs="?")
    args = parser.parse_args()
    try:
        if args.command == "native-host":
            native_host()
            return
        endpoints = sessions(socket_directory())
        if args.session:
            endpoints = [p for p in endpoints if p.stem == args.session]
        if not endpoints:
            raise ValueError("No bridge connected. Click Forge Tab Bridge in an HTTP(S) tab.")
        if args.command == "tabs":
            result = [
                dict(tab, session=p.stem)
                for p in endpoints for tab in request(p, {"method": "tabs"})
            ]
        else:
            if len(endpoints) != 1:
                raise ValueError("Multiple browser sessions; select one with --session")
            message = {"method": args.command, "tabId": args.tab_id}
            if args.command == "eval":
                message["expression"] = (
                    sys.stdin.read(MAX_MESSAGE + 1) if args.expression == "-" else args.expression
                )
            result = request(endpoints[0], message)
        print(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2))
    except (ValueError, OSError, EOFError, KeyError) as error:
        print(f"chrome-tab: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
