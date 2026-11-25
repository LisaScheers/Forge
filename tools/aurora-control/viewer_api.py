"""Client for Aurora Viewer's local control bridge (forge's viewer patch).

The viewer listens on ``<directory>/control.sock`` when it was started with
``AURORA_CONTROL_DIR=<directory>``. Each request is one JSON line; each reply
is one JSON line with ``result`` or ``error``, plus ``request_id``.
"""

from __future__ import annotations

import json
import os
import socket
import uuid
from pathlib import Path
from typing import Any

SOCKET = "control.sock"
ENV = "AURORA_CONTROL_DIR"
# The viewer answers within 30 seconds or replies "timeout" itself.
DEFAULT_TIMEOUT = 35.0


class ViewerUnavailable(OSError):
    """No viewer with the bridge listens at the directory; nothing was sent."""


def default_directory() -> Path | None:
    value = os.environ.get(ENV)
    return Path(value) if value else None


def socket_path(directory: os.PathLike[str] | str) -> Path:
    return Path(directory) / SOCKET


def request(
    directory: os.PathLike[str] | str,
    tool: str,
    arguments: dict[str, Any] | None = None,
    request_id: str | None = None,
    timeout: float = DEFAULT_TIMEOUT,
) -> dict[str, Any]:
    """Send one request and return the reply envelope.

    Raises ViewerUnavailable when the endpoint cannot be reached. Once the
    request is sent, a lost connection or a timeout returns an error envelope
    that keeps the request_id: inspect ``viewer_events`` with it before any
    retry, and never replay a mutation automatically.
    """
    if not isinstance(tool, str) or not tool:
        raise ValueError("tool must be a non-empty string")
    if arguments is not None and not isinstance(arguments, dict):
        raise ValueError("arguments must be a JSON object")
    request_id = request_id or str(uuid.uuid4())
    line = json.dumps({"request_id": request_id, "tool": tool, "arguments": arguments or {}}) + "\n"
    path = socket_path(directory)
    connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    connection.settimeout(timeout)
    try:
        try:
            connection.connect(str(path))
        except OSError as error:
            # nothing was sent: no endpoint, a stale socket, or no access
            raise ViewerUnavailable(
                f"no Aurora control bridge at {path} ({error.strerror or error}): launch the viewer with {ENV}={directory}"
            ) from error
        try:
            connection.sendall(line.encode())
            reply = _read_line(connection)
        except socket.timeout:
            return _lost(request_id, "timeout", "no reply in time; the command may still run")
        except OSError as error:
            return _lost(request_id, "disconnected", f"connection lost: {error}")
    finally:
        connection.close()
    if reply is None:
        return _lost(request_id, "disconnected", "the viewer closed the connection without a reply")
    try:
        answer = json.loads(reply)
    except json.JSONDecodeError:
        return _lost(request_id, "protocol", "the reply is not JSON")
    if not isinstance(answer, dict) or ("result" in answer) == ("error" in answer):
        return _lost(request_id, "protocol", "the reply has neither result nor error")
    answer.setdefault("request_id", request_id)
    return answer


def _read_line(connection: socket.socket) -> str | None:
    chunks = []
    while True:
        chunk = connection.recv(65536)
        if not chunk:
            return None
        newline = chunk.find(b"\n")
        if newline >= 0:
            chunks.append(chunk[:newline])
            return b"".join(chunks).decode()
        chunks.append(chunk)


def _lost(request_id: str, code: str, message: str) -> dict[str, Any]:
    return {
        "request_id": request_id,
        "error": {
            "code": code,
            "message": f"{message}; inspect viewer_events with request_id {request_id} before any retry",
        },
    }


class ViewerError(RuntimeError):
    def __init__(self, request_id: str, error: dict[str, Any]):
        super().__init__(f"{error.get('code')}: {error.get('message')} (request {request_id})")
        self.request_id = request_id
        self.error = error


def call(directory: os.PathLike[str] | str, tool: str, **arguments: Any) -> Any:
    """``request`` that returns the result or raises ViewerError."""
    answer = request(directory, tool, arguments)
    if "error" in answer:
        raise ViewerError(answer["request_id"], answer["error"])
    return answer["result"]
