import json
from pathlib import Path
import tempfile
import unittest

from aiohttp.test_utils import TestClient, TestServer

from parser import digest, merge_messages, normalize_tokens, parse_capture
from server import create_app
from store import Store


def capture(text="Hello <script>alert(1)</script>", identity="one", response="resp_1", websocket=False):
    request = {"model": "gpt-6.1-sol", "client_metadata": {"thread_id": "thread-1"},
               "input": [{"role": "user", "content": text}]}
    output = {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "Answer"}]}
    terminal = {"type": "response.completed", "response": {"id": response, "status": "completed", "output": []}}
    header = "=== REQUEST INFO ===\nTimestamp: 2026-11-05T10:00:00Z\nURL: /v1/responses\n=== HEADERS ===\nUser-Agent: codex-cli\n"
    events = ["[2026-11-05T10:00:00Z] request", json.dumps({"type": "response.create", **request}),
              "[2026-11-05T10:00:01Z] response", json.dumps({"type": "response.output_item.done", "item": output}), json.dumps(terminal)]
    if websocket:
        transcript = header + "=== WEBSOCKET TIMELINE ===\n" + "\n".join(events)
    else:
        transcript = header + "=== REQUEST BODY ===\n" + json.dumps(request) + "\n=== RESPONSE ===\n" + "\n".join('data: ' + line for line in events[3:])
    return {"capture_id": digest(identity), "file_name": identity + ".log", "observed_at": "2026-11-05 10:00:04.000", "bytes": len(transcript.encode()), "transcript": transcript}


class Backend:
    def __init__(self, row):
        self.row = row

    def transcript(self, identity):
        return self.row["transcript"]

    def query(self, sql, **parameters):
        if "ai_usage.files" in sql:
            return [{key: value for key, value in self.row.items() if key != "transcript"}]
        if "ai_usage.requests" in sql:
            return [self.row]
        return [{"response_key": "resp_1", "token_category": key, "token_count": value}
                for key, value in {"input_tokens": 20, "output_tokens": 7, "total_tokens": 27, "input_tokens_details.cached_tokens": 8}.items()]


class ParserTests(unittest.TestCase):
    def test_nonstreaming_response_object_keeps_text_and_usage_identity(self):
        row = capture()
        row["transcript"] = row["transcript"].split("=== RESPONSE ===")[0] + "=== RESPONSE ===\n" + json.dumps({
            "object": "response", "id": "resp_direct", "status": "completed",
            "output": [{"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "Direct answer"}]}]})
        turn = parse_capture(row, {"resp_direct": {"input_tokens": 5, "output_tokens": 2}})[0]
        self.assertEqual(turn["output"][0]["text"], "Direct answer")
        self.assertEqual(turn["total_tokens"], 7)
        self.assertEqual(turn["status"], "success")

    def test_websocket_timestamps_and_empty_terminal_output_preserve_message(self):
        row = capture(websocket=True)
        turn = parse_capture(row, {"resp_1": {"input_tokens": 20, "output_tokens": 7}})[0]
        self.assertEqual(turn["output"][0]["text"], "Answer")
        self.assertEqual(turn["session_id"], "thread-1")
        self.assertEqual(turn["total_tokens"], 27)

    def test_missing_usage_stays_unknown_and_subsets_are_not_added_twice(self):
        self.assertIsNone(normalize_tokens({})["total_tokens"])
        self.assertEqual(normalize_tokens({"input_tokens": 20, "output_tokens": 7, "input_tokens_details.cached_tokens": 8, "output_tokens_details.reasoning_tokens": 3})["total_tokens"], 27)
        self.assertEqual(normalize_tokens({"promptTokenCount": 20, "candidatesTokenCount": 7, "thoughtsTokenCount": 3})["output_tokens"], 10)
        self.assertEqual(normalize_tokens({"input_tokens": 20, "output_tokens": 7, "cache_read_input_tokens": 8})["total_tokens"], 35)

    def test_context_replay_and_repeated_user_turns(self):
        user = {"role": "user", "text": "Again"}
        answer = {"role": "assistant", "text": "Answer"}
        history = merge_messages([user, answer], [user, answer, user])
        self.assertEqual(history, [user, answer, user])
        self.assertEqual(merge_messages([user, answer], [user]), [user, answer, user])

    def test_calls_without_session_ids_do_not_become_one_conversation(self):
        rows = [capture(identity=name) for name in ("one", "two")]
        for row in rows:
            row["transcript"] = row["transcript"].replace('"client_metadata": {"thread_id": "thread-1"}, ', '')
        ids = [parse_capture(row, {})[0]["conversation_id"] for row in rows]
        self.assertNotEqual(*ids)


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.backend = Backend(capture())
        self.store = Store(Path(self.directory.name) / "index.sqlite", self.backend)

    def test_sync_idempotence_search_and_capture_revision(self):
        self.store.sync()
        self.store.sync()
        self.store = Store(self.store.path, self.backend)
        self.assertEqual(self.store.status()["captures"], 1)
        self.assertEqual(self.store.analytics({})["totals"]["total_tokens"], 27)
        found = self.store.conversations({"q": 'Hello " OR 1=1 --'})
        self.assertEqual(found["total"], 0)
        found = self.store.conversations({"q": "Hello"})
        self.assertEqual(found["total"], 1)
        detail = self.store.conversation(found["items"][0]["id"])
        self.assertEqual(len(detail["messages"]), 2)
        self.backend.row = capture(text="Replacement", identity="changed")
        self.backend.row["file_name"] = "one.log"
        self.store.sync()
        self.assertEqual(self.store.status()["captures"], 1)
        self.assertEqual(self.store.analytics({})["totals"]["total_tokens"], 27)
        self.assertEqual(self.store.conversations({"q": "Hello"})["total"], 0)


class HTTPTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.row = capture()
        self.store = Store(Path(self.directory.name) / "index.sqlite", Backend(self.row))
        self.store.sync()
        self.client = TestClient(TestServer(create_app(self.store, sync=False)))
        await self.client.start_server()
        self.addAsyncCleanup(self.client.close)

    async def test_auth_boundary_filters_and_raw_roundtrip(self):
        response = await self.client.get('/api/conversations')
        self.assertEqual(response.status, 401)
        response = await self.client.get('/api/conversations', headers={"X-AI-User": "other"})
        self.assertEqual(response.status, 401)
        headers = {"X-AI-User": "lisa"}
        response = await self.client.get('/api/conversations?days=0', headers=headers)
        data = await response.json()
        self.assertEqual(data["total"], 1)
        response = await self.client.get('/api/conversations/' + data["items"][0]["id"], headers=headers)
        detail = await response.json()
        self.assertIn('<script>', detail["messages"][0]["text"])
        self.assertIn("script-src 'self'", response.headers["Content-Security-Policy"])
        response = await self.client.get('/api/captures/' + self.row['capture_id'] + '/raw', headers=headers)
        self.assertEqual(await response.text(), self.row['transcript'])
        self.assertIn('attachment;', response.headers['Content-Disposition'])
        for route in ('/api/conversations?days=-1', '/api/analytics?days=potato', '/api/conversations?offset=-1'):
            response = await self.client.get(route, headers=headers)
            self.assertEqual(response.status, 400)
        response = await self.client.get('/api/requests/not-an-id', headers=headers)
        self.assertEqual(response.status, 404)


if __name__ == '__main__':
    unittest.main()
