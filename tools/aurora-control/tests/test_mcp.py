import base64
import io
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import mcp_server  # noqa: E402
from fake_viewer import FakeViewer, echo  # noqa: E402

SKILL = Path(__file__).resolve().parents[3] / "modules/development/ai-skills/skills/aurora-viewer-control"


def exchange(server, *messages):
    """Runs newline-delimited JSON-RPC through serve() and returns the replies."""
    reader = io.StringIO("".join(m if isinstance(m, str) else json.dumps(m) + "\n" for m in messages))
    writer = io.StringIO()
    mcp_server.serve(server, reader, writer)
    return [json.loads(line) for line in writer.getvalue().splitlines()]


def rpc(id_, method, params=None):
    message = {"jsonrpc": "2.0", "id": id_, "method": method}
    if params is not None:
        message["params"] = params
    return message


class FramingTests(unittest.TestCase):
    def setUp(self):
        self.viewer = FakeViewer(echo)
        self.addCleanup(self.viewer.close)
        self.server = mcp_server.Server(self.viewer.directory)

    def test_initialize_ping_and_notifications(self):
        replies = exchange(
            self.server,
            rpc(1, "initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "t"}}),
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            rpc(2, "ping"),
        )
        self.assertEqual([r["id"] for r in replies], [1, 2], "notifications get no reply")
        result = replies[0]["result"]
        self.assertEqual(result["protocolVersion"], "2025-03-26")
        self.assertEqual(result["capabilities"], {"tools": {}, "resources": {}})
        self.assertIn("aurora://guide", result["instructions"])
        self.assertEqual(replies[1]["result"], {})

    def test_an_unknown_protocol_version_gets_the_newest(self):
        (reply,) = exchange(self.server, rpc(1, "initialize", {"protocolVersion": "1999-01-01"}))
        self.assertEqual(reply["result"]["protocolVersion"], mcp_server.PROTOCOL_VERSIONS[0])

    def test_errors_follow_json_rpc(self):
        replies = exchange(self.server, "not json\n", rpc(3, "nope"), {"id": 4}, rpc(5, "tools/call", {"name": "viewer_nope"}), rpc(6, "tools/call", []))
        self.assertEqual([r["error"]["code"] for r in replies], [-32700, -32601, -32600, -32602, -32602])
        self.assertEqual([r["id"] for r in replies], [None, 3, 4, 5, 6])

    def test_a_batch_gets_a_batch(self):
        (reply,) = exchange(self.server, json.dumps([rpc(1, "ping"), rpc(2, "ping")]) + "\n")
        self.assertEqual([r["id"] for r in reply], [1, 2])

    def test_the_tool_surface_matches_the_skill(self):
        (reply,) = exchange(self.server, rpc(1, "tools/list"))
        names = [t["name"] for t in reply["result"]["tools"]]
        self.assertEqual(
            names,
            [
                "viewer_state", "viewer_query", "viewer_events", "viewer_settings", "viewer_move", "viewer_camera",
                "viewer_object", "viewer_build", "viewer_inventory", "viewer_contents", "viewer_script",
                "viewer_notifications", "viewer_chat", "viewer_ui", "viewer_input", "viewer_capture",
            ],
        )
        for tool in reply["result"]["tools"]:
            self.assertEqual(tool["inputSchema"]["type"], "object", tool["name"])
        # the forge skill is the contract; the package build sees only this tool
        if SKILL.exists():
            skill = (SKILL / "SKILL.md").read_text()
            for name in names:
                self.assertIn(f"`{name}`", skill)

    def test_resources_are_the_guide_and_the_catalog(self):
        replies = exchange(
            self.server,
            rpc(1, "resources/list"),
            rpc(2, "resources/read", {"uri": "aurora://guide"}),
            rpc(3, "resources/read", {"uri": "aurora://tools"}),
            rpc(4, "resources/read", {"uri": "aurora://nope"}),
        )
        self.assertEqual([r["uri"] for r in replies[0]["result"]["resources"]], ["aurora://guide", "aurora://tools"])
        self.assertIn("Never handle credentials", replies[1]["result"]["contents"][0]["text"])
        self.assertEqual(json.loads(replies[2]["result"]["contents"][0]["text"]), mcp_server.TOOLS)
        self.assertEqual(replies[3]["error"]["code"], -32602)

    def test_a_call_carries_the_envelope(self):
        replies = exchange(
            self.server,
            rpc(1, "tools/call", {"name": "viewer_query", "arguments": {"topic": "chat", "limit": 5}}),
            rpc(2, "tools/call", {"name": "viewer_chat", "arguments": {"op": "say", "text": "x"}}),
        )
        ok, refused = (r["result"] for r in replies)
        self.assertFalse(ok["isError"])
        self.assertEqual(ok["structuredContent"]["result"]["arguments"], {"topic": "chat", "limit": 5})
        self.assertEqual(json.loads(ok["content"][0]["text"]), ok["structuredContent"])
        self.assertTrue(refused["isError"])
        self.assertEqual(refused["structuredContent"]["error"]["code"], "refused")
        self.assertIn("request_id", refused["structuredContent"])

    def test_no_viewer_is_a_tool_error_not_a_crash(self):
        server = mcp_server.Server(Path("/tmp/acf-none"))
        (reply,) = exchange(server, rpc(1, "tools/call", {"name": "viewer_state"}))
        self.assertTrue(reply["result"]["isError"])
        self.assertEqual(reply["result"]["structuredContent"]["error"]["code"], "unavailable")


class CaptureTests(unittest.TestCase):
    def test_a_capture_waits_and_returns_an_image(self):
        png = base64.b64encode(b"\x89PNG fake").decode()
        polls = []

        def viewer(request):
            args = request["arguments"]
            if args["op"] == "start":
                result = {"status": "pending", "capture_id": 7}
            else:
                polls.append(args["capture_id"])
                result = {"status": "pending", "capture_id": 7} if len(polls) < 3 else {
                    "status": "done", "capture_id": 7, "width": 2, "height": 1, "png_base64": png,
                    "window_pixels": [4, 2], "ui_pixels_per_point": 2.0,
                }
            return {"request_id": request["request_id"], "result": result}

        fake = FakeViewer(viewer)
        self.addCleanup(fake.close)
        (reply,) = exchange(mcp_server.Server(fake.directory), rpc(1, "tools/call", {"name": "viewer_capture", "arguments": {"max_width": 800}}))
        result = reply["result"]
        self.assertFalse(result["isError"])
        self.assertEqual(result["content"][0], {"type": "image", "data": png, "mimeType": "image/png"})
        self.assertNotIn("png_base64", result["structuredContent"]["result"])
        self.assertEqual(result["structuredContent"]["result"]["window_pixels"], [4, 2])
        self.assertEqual(polls, [7, 7, 7])
        self.assertEqual(fake.requests[0]["arguments"], {"max_width": 800, "op": "start"})

    def test_explicit_ops_pass_through(self):
        fake = FakeViewer(echo)
        self.addCleanup(fake.close)
        (reply,) = exchange(mcp_server.Server(fake.directory), rpc(1, "tools/call", {"name": "viewer_capture", "arguments": {"op": "poll"}}))
        self.assertEqual(reply["result"]["structuredContent"]["result"]["arguments"], {"op": "poll"})


if __name__ == "__main__":
    unittest.main()
