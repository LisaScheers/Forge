"""A stand-in for the viewer's endpoint: one JSON line in, one line out."""

from __future__ import annotations

import json
import os
import socket
import tempfile
import threading
from pathlib import Path
from typing import Any, Callable

Handler = Callable[[dict[str, Any]], Any]


class FakeViewer:
    """Listens at <directory>/control.sock and answers with ``handler``.

    The handler returns a reply object, the bytes to send as-is, or None to
    close the connection without a reply.
    """

    def __init__(self, handler: Handler):
        # macOS keeps socket paths under 104 bytes; the default temp dir is long
        self.parent = Path(tempfile.mkdtemp(prefix="acf-", dir="/tmp"))
        self.directory = self.parent / "c"
        self.directory.mkdir(mode=0o700)
        self.handler = handler
        self.requests: list[dict[str, Any]] = []
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(str(self.directory / "control.sock"))
        self.listener.listen()
        self.thread = threading.Thread(target=self._accept, daemon=True)
        self.thread.start()

    def _accept(self) -> None:
        while True:
            try:
                connection, _ = self.listener.accept()
            except OSError:
                return
            threading.Thread(target=self._serve, args=(connection,), daemon=True).start()

    def _serve(self, connection: socket.socket) -> None:
        with connection, connection.makefile("rwb") as stream:
            for line in stream:
                request = json.loads(line)
                self.requests.append(request)
                reply = self.handler(request)
                if reply is None:
                    return
                data = reply if isinstance(reply, bytes) else (json.dumps(reply) + "\n").encode()
                stream.write(data)
                stream.flush()

    def close(self) -> None:
        self.listener.close()
        for path in (self.directory / "control.sock",):
            if path.exists():
                os.unlink(path)
        self.directory.rmdir()
        self.parent.rmdir()


def echo(request: dict[str, Any]) -> dict[str, Any]:
    """Replies like the viewer: refused for viewer_chat, the arguments otherwise."""
    if request["tool"] == "viewer_chat":
        return {"request_id": request["request_id"], "error": {"code": "refused", "message": "no"}}
    return {"request_id": request["request_id"], "result": {"tool": request["tool"], "arguments": request["arguments"]}}
