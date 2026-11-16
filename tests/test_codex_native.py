"""Exercise the installed Codex recorder against local HTTP and WebSocket fixtures."""

import asyncio
import json
import os
from pathlib import Path
import tempfile
import unittest

from aiohttp import web
from codex_trace import captures
from ingest import observations
from parser import digest, parse_capture


@unittest.skipUnless(os.environ.get("CODEX_CAPTURE_BINARY"), "requires the patched Codex package")
class NativeRecorderTests(unittest.IsolatedAsyncioTestCase):
    async def exercise(self, websocket):
        requests = []
        transports = []
        connections = []
        marker = "Native capture 🦊 " + "x" * 10000
        usage = {"input_tokens": 101, "input_tokens_details": {"cached_tokens": 40},
                 "output_tokens": 17, "output_tokens_details": {"reasoning_tokens": 5},
                 "total_tokens": 118, "future_tokens": 3}
        tool_usage = {"image_gen": {"input_tokens": 9, "output_tokens": 10}}

        def events(identity, warmup=False):
            item = {"type": "message", "id": "msg_fixture", "role": "assistant", "status": "completed",
                    "content": [{"type": "output_text", "text": marker, "annotations": []}]}
            if warmup:
                return [{"type": "response.completed", "response": {"id": "resp_warmup", "output": [],
                    "usage": {"input_tokens": 11, "output_tokens": 0, "total_tokens": 11, "warmup_tokens": 1}}}]
            return [
                {"type": "response.created", "response": {"id": identity}},
                {"type": "future.extension", "unrecognized_content": "preserve this"},
                {"type": "response.output_item.added", "output_index": 0, "item": {**item, "content": []}},
                {"type": "response.output_text.delta", "item_id": item["id"], "output_index": 0,
                 "content_index": 0, "delta": marker},
                {"type": "response.output_item.done", "output_index": 0, "item": item},
                {"type": "response.completed", "response": {"id": identity, "object": "response",
                    "model": "gpt-6.1-sol", "status": "completed", "output": [item],
                    "usage": usage, "tool_usage": tool_usage}},
            ]

        async def handler(request):
            connections.append((request.method, request.headers.get("Upgrade", ""), request.path))
            if request.headers.get("Upgrade", "").lower() == "websocket":
                if not websocket:
                    return web.Response(status=426)
                socket = web.WebSocketResponse()
                await socket.prepare(request)
                async for message in socket:
                    payload = json.loads(message.data)
                    requests.append(payload)
                    transports.append("websocket")
                    for event in events("resp_fixture", payload.get("generate") is False):
                        await socket.send_json(event)
                return socket
            if request.method == "POST":
                requests.append(await request.json())
                transports.append("http")
                body = "".join("event: " + e["type"] + "\ndata: " + json.dumps(e) + "\n\n"
                               for e in events("resp_fixture"))
                return web.Response(text=body, content_type="text/event-stream")
            return web.json_response({"object": "list", "data": []})

        app = web.Application(client_max_size=20 * 1024 * 1024)
        app.router.add_route("*", "/{tail:.*}", handler)
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, "127.0.0.1", 0)
        await site.start()
        port = site._server.sockets[0].getsockname()[1]
        try:
            with tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                (home / "auth.json").write_text('{"OPENAI_API_KEY":"local-fixture-only"}')
                env = dict(os.environ, HOME=directory, CODEX_HOME=directory,
                           CODEX_ROLLOUT_TRACE_ROOT=str(home / "traces"),
                           HTTP_PROXY="", HTTPS_PROXY="", ALL_PROXY="", NO_PROXY="127.0.0.1,localhost",
                           http_proxy="", https_proxy="", all_proxy="", no_proxy="127.0.0.1,localhost")
                process = await asyncio.create_subprocess_exec(
                    os.environ["CODEX_CAPTURE_BINARY"], "exec", "--skip-git-repo-check", "-C", directory,
                    "-m", "gpt-6.1-sol", "-c", 'model_provider="openai"',
                    "-c", f'openai_base_url="http://127.0.0.1:{port}/v1"', "Reply with the fixture message.",
                    stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE, env=env)
                try:
                    output, errors = await asyncio.wait_for(process.communicate(), 60)
                finally:
                    if process.returncode is None:
                        process.kill()
                        await process.wait()
                self.assertEqual(process.returncode, 0, errors.decode()[-4000:])
                self.assertIn(marker, output.decode())
                self.assertTrue(requests)
                self.assertEqual(set(transports), {"websocket" if websocket else "http"},
                                 (connections, errors.decode().replace(marker, "<fixture answer>")[-6000:]))
                bundle, = (home / "traces").iterdir()
                recorded = [json.loads(line) for line in (bundle / "trace.jsonl").read_text().splitlines()]
                raw = [row["payload"] for row in recorded
                       if row["payload"]["type"] == "other" and row["payload"].get("kind") == "raw_response"]
                frames = [json.loads(json.loads((bundle / ref["path"]).read_text())["data"])
                          for row in raw for ref in row["payloads"]]
                completed = [frame["response"] for frame in frames if frame["type"] == "response.completed"
                             and frame["response"]["id"] == "resp_fixture"]
                self.assertEqual(len(completed), 1)
                self.assertEqual(completed[0]["usage"], usage)
                self.assertEqual(completed[0]["tool_usage"], tool_usage)
                self.assertTrue(any(frame.get("unrecognized_content") == "preserve this" for frame in frames))
                self.assertTrue(any(frame.get("delta") == marker for frame in frames))
                starts = [row["payload"] for row in recorded if row["payload"]["type"] == "inference_started"]
                captured_requests = [json.loads((bundle / row["request_payload"]["path"]).read_text()) for row in starts]
                request = next(r for r in captured_requests if "Reply with the fixture message." in json.dumps(r))
                self.assertTrue(request.get("tools") or any(item.get("type") == "additional_tools" for item in request["input"]))
                if any(r.get("generate") is False for r in requests):
                    warmup = next(frame["response"] for frame in frames if frame.get("response", {}).get("id") == "resp_warmup")
                    self.assertEqual(warmup["usage"]["warmup_tokens"], 1)
                projected = [data.decode() for _, _, data in captures(bundle)]
                turns = [turn for text in projected for turn in parse_capture({
                    "capture_id": digest(text), "file_name": "fixture.log", "transcript": text,
                    "observed_at": "2026-11-15 10:00:00.000", "bytes": len(text.encode()),
                }, {})]
                self.assertTrue(any(message["text"] == marker for turn in turns for message in turn["output"]))
                usage_rows = [row for text in projected for row in observations(text.splitlines())]
                self.assertTrue(any(row["tokens"].get("future_tokens") == 3 for row in usage_rows))
                self.assertTrue(any(row["tokens"].get("tool_usage.image_gen.output_tokens") == 10
                                    for row in usage_rows))
        finally:
            await runner.cleanup()

    async def test_http_raw_capture(self):
        await self.exercise(False)

    async def test_websocket_raw_capture(self):
        await self.exercise(True)


if __name__ == "__main__":
    unittest.main()
