"""End-to-end check of the control bridge against Aurora's offline demo.

    AURORA_DEMO=1 AURORA_CONTROL_DIR=/tmp/aurora-e2e aurora-viewer &
    python3 e2e_demo.py /tmp/aurora-e2e

Refuses to run unless viewer_state reports demo=true: the demo has no grid
connection, so the chat it sends reaches no one. It restores every setting,
panel and camera zoom it changes.
"""

from __future__ import annotations

import base64
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import viewer_api

HERE = Path(__file__).resolve().parent


def wait(predicate, what: str, deadline: float = 60.0, interval: float = 0.2):
    end = time.monotonic() + deadline
    last = None
    while time.monotonic() < end:
        try:
            last = predicate()
        except viewer_api.ViewerUnavailable:
            last = None
        if last:
            return last
        time.sleep(interval)
    raise AssertionError(f"timed out waiting for {what} (last: {last!r})")


class Check:
    def __init__(self, directory: Path):
        self.directory = directory
        self.passed: list[str] = []
        self.covered = False

    def call(self, tool: str, **arguments: Any) -> Any:
        return viewer_api.call(self.directory, tool, **arguments)

    def refused(self, tool: str, code: str, **arguments: Any) -> dict[str, Any]:
        answer = viewer_api.request(self.directory, tool, arguments)
        assert "error" in answer, f"{tool} {arguments} should fail: {answer}"
        assert answer["error"]["code"] == code, answer
        return answer

    def ok(self, name: str) -> None:
        self.passed.append(name)
        print(f"ok  {name}", flush=True)

    def run(self) -> None:
        state = wait(lambda: viewer_api.request(self.directory, "viewer_state").get("result"), "the endpoint")
        if state["demo"] is not True:
            # an explicit check: assert would vanish under python -O
            raise SystemExit("refusing: this viewer is not the offline demo")
        state = wait(lambda: (s := self.call("viewer_state"))["in_world"] and s, "the demo world", 180)
        assert state["pid"] > 0 and state["agent"]["id"]
        cursor = state["events"]["cursor"]
        self.ok(f"state: pid {state['pid']}, region {state['region'] and state['region']['name']}, cursor {cursor}")

        self.refused("viewer_nope", "unknown_tool")
        self.refused("viewer_move", "unknown_op", op="teleport")
        self.refused("viewer_query", "invalid_argument", topic="secrets")
        self.refused("viewer_settings", "refused", op="get", pointer="/username")
        self.refused("viewer_settings", "refused", op="set", pointer="/rlva_enabled", value=False)
        self.ok("unknown tools, ops, topics and hidden settings are refused")

        for topic in ("chat", "conversations", "avatars", "objects", "huds", "attachments", "friends", "groups", "notifications", "inventory"):
            page = self.call("viewer_query", topic=topic, limit=5)
            assert "rows" in page and len(page["rows"]) <= 5, (topic, page)
        objects = self.call("viewer_query", topic="objects", radius=64, limit=200)
        self.ok(f"queries: {objects['total']} objects within 64 m")
        if objects["rows"]:
            detail = self.call("viewer_query", topic="object", id=objects["rows"][0]["id"])
            assert detail["id"] == objects["rows"][0]["id"] and len(detail["rotation"]) == 4
            self.ok("object detail")

        root = state["inventory_root"]
        if root:
            self.call("viewer_inventory", op="fetch", id=root)
            listing = wait(lambda: (q := self.call("viewer_query", topic="inventory", parent=root))["state"] == "fetched" and q, "the inventory root", 30)
            self.ok(f"inventory root: {listing['total']} entries")

        original = self.call("viewer_settings", op="get", pointer="/draw_distance")["value"]
        changed = self.call("viewer_settings", op="set", pointer="/draw_distance", value=96.0)
        assert changed["previous"] == original and changed["value"] == 96.0 and changed["persisted"] is False, changed
        self.refused("viewer_settings", "invalid_argument", op="set", pointer="/draw_distance", value="far")
        self.call("viewer_settings", op="set", pointer="/draw_distance", value=original)
        assert self.call("viewer_settings", op="get", pointer="/draw_distance")["value"] == original
        self.ok("settings: read, typed write, read back, restore")

        before = self.call("viewer_state")["agent"]["position"]
        held = self.call("viewer_move", op="hold", directions=["forward"], duration_ms=60_000)
        assert held["duration_ms"] == 10_000, "holds are cut to the 10-second lease"
        self.call("viewer_move", op="hold", directions=["forward"], duration_ms=1500)
        assert self.call("viewer_state")["input"]["hold"] == ["Forward"]
        time.sleep(1.8)
        after = self.call("viewer_state")
        assert after["input"]["hold"] == [] or after["input"]["hold_ms"] == 0
        self.call("viewer_move", op="stop")
        moved = sum((a - b) ** 2 for a, b in zip(after["agent"]["position"], before)) ** 0.5
        self.ok(f"movement: held forward, lease ended, moved {moved:.2f} m")

        camera = self.call("viewer_camera", op="get")
        zoomed = self.call("viewer_camera", op="zoom", fraction=0.5)
        assert abs(zoomed["zoom"] - 0.5) < 0.05, zoomed
        self.call("viewer_camera", op="zoom", fraction=camera["zoom"])
        self.ok("camera zoom and restore")

        panels = {p["name"]: p["open"] for p in self.call("viewer_ui", op="list")["panels"]}
        self.call("viewer_ui", op="open", name="people")
        assert {p["name"]: p["open"] for p in self.call("viewer_ui", op="list")["panels"]}["people"] is True
        self.call("viewer_ui", op="close" if not panels["people"] else "open", name="people")
        actions = self.call("viewer_ui", op="actions")["actions"]
        assert any(a["name"] == "ResetCamera" for a in actions)
        self.call("viewer_ui", op="run", action="ResetCamera")
        self.ok(f"ui: panels and {len(actions)} actions")

        window = self.call("viewer_state")["window"]
        x, y = window["width_points"] / 2, window["height_points"] / 2
        self.call("viewer_input", op="move", x=x, y=y)
        self.refused("viewer_input", "invalid_argument", op="click", x=-1, y=0)
        self.call("viewer_input", op="drag_start", x=x, y=y)
        self.refused("viewer_input", "unavailable", op="game_click", x=x, y=y)
        self.call("viewer_input", op="drag_move", x=x + 20, y=y)
        assert self.call("viewer_state")["input"]["drag"] is True
        self.call("viewer_input", op="drag_end")
        wait(lambda: not self.call("viewer_state")["input"]["pointer_down"], "the drag release", 5)
        self.ok("input: egui move, native drag with lease, release")

        capture = self.call("viewer_capture", op="start", max_width=640)
        try:
            shot = wait(lambda: (c := self.call("viewer_capture", op="poll", capture_id=capture["capture_id"]))["status"] != "pending" and c, "the capture", 20)
        except AssertionError:
            # macOS draws nothing for a covered window
            if not self.call("viewer_capture", op="poll")["occluded"]:
                raise
            self.covered = True
            print("skip capture: the viewer window is covered; uncover it to check captures", flush=True)
        else:
            assert shot["status"] == "done" and shot["width"] <= 640, {k: v for k, v in shot.items() if k != "png_base64"}
            assert base64.b64decode(shot["png_base64"])[:8] == b"\x89PNG\r\n\x1a\n"
            self.ok(f"capture: {shot['width']}x{shot['height']} PNG of a {shot['window_pixels']} window")

        said = viewer_api.request(self.directory, "viewer_chat", {"op": "say", "text": "control bridge demo check"}, request_id="e2e-say")
        assert said["result"]["status"] == "dispatched", said
        line = wait(
            lambda: next((e for e in self.call("viewer_events", after=cursor, limit=512)["events"] if e["kind"] == "chat" and "control bridge demo check" in e["data"]["text"]), None),
            "the nearby chat line",
            10,
        )
        page = self.call("viewer_events", after=cursor, request_id="e2e-say")
        assert page["receipt"]["ok"] is True and page["receipt"]["op"] == "say", page["receipt"]
        assert any(e["kind"] == "command" for e in page["events"]), page["events"]
        latest = self.call("viewer_query", topic="chat", limit=1)["rows"][0]
        assert "control bridge demo check" in latest["text"], latest
        self.ok(f"chat: offline say, chat event #{line['seq']}, receipt and command event")

        conversations = self.call("viewer_query", topic="conversations")["rows"]
        if conversations:
            lines = self.call("viewer_query", topic="im", id=conversations[0]["id"], limit=3)
            assert "unread" in lines
        self.ok(f"conversations: {len(conversations)} listed")

        self.call("viewer_notifications", op="list")
        self.refused("viewer_notifications", "not_found", op="dismiss", id=999_999_999)
        self.ok("notifications list and unknown id")

        self.mcp(state["pid"])

    def mcp(self, pid: int) -> None:
        server = subprocess.Popen(
            [sys.executable, "-B", str(HERE / "mcp_server.py"), "--directory", str(self.directory)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )

        def rpc(id_: int, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
            server.stdin.write(json.dumps({"jsonrpc": "2.0", "id": id_, "method": method, "params": params or {}}) + "\n")
            server.stdin.flush()
            return json.loads(server.stdout.readline())

        try:
            assert rpc(1, "initialize", {"protocolVersion": "2025-06-18"})["result"]["serverInfo"]["name"] == "aurora-control"
            assert len(rpc(2, "tools/list")["result"]["tools"]) == 16
            state = rpc(3, "tools/call", {"name": "viewer_state", "arguments": {}})["result"]
            assert not state["isError"] and state["structuredContent"]["result"]["pid"] == pid
            image = rpc(4, "tools/call", {"name": "viewer_capture", "arguments": {"max_width": 320}})["result"]
            result = image["structuredContent"]["result"]
            if result["status"] == "done":
                assert not image["isError"] and image["content"][0]["type"] == "image", result
                self.covered = False
            else:
                assert result["status"] == "pending" and result["occluded"], result
            guide = rpc(5, "resources/read", {"uri": "aurora://guide"})["result"]["contents"][0]["text"]
            assert "viewer_state" in guide
            self.ok("mcp: initialize, 16 tools, viewer_state, capture" + (" (pending: window covered)" if self.covered else " image") + ", guide")
        finally:
            server.stdin.close()
            server.wait(timeout=10)


def main() -> int:
    directory = Path(sys.argv[1] if len(sys.argv) > 1 else viewer_api.default_directory() or "")
    if not directory.is_absolute():
        print("usage: e2e_demo.py /absolute/AURORA_CONTROL_DIR", file=sys.stderr)
        return 2
    check = Check(directory)
    check.run()
    print(f"{len(check.passed)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
