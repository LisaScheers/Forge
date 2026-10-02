import asyncio
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from aiohttp import ClientSession, web
from aiohttp.test_utils import TestClient, TestServer

from openai_plan import (
    MODEL, PlanClient, application, chat_response, completed_response,
    responses_request, save_credentials, token_record,
)


async def stream(*events):
    for event in events:
        yield f"data: {json.dumps(event)}\n".encode()
        yield b"\n"


class StreamTests(unittest.IsolatedAsyncioTestCase):
    async def test_success_requires_terminal_completion(self):
        response = {"status": "completed", "id": "resp_1", "output": [
            {"type": "message", "content": [{"type": "output_text", "text": '{"entities":[]}'}]}]}
        actual = await completed_response(stream(
            {"type": "response.output_text.delta", "delta": "ignored partial"},
            {"type": "response.completed", "response": response},
        ))
        self.assertEqual(chat_response(actual)["choices"][0]["message"]["content"], '{"entities":[]}')

    async def test_partial_output_never_counts_as_success(self):
        with self.assertRaises(web.HTTPBadGateway):
            await completed_response(stream({"type": "response.output_text.delta", "delta": "partial"}))

    async def test_final_items_survive_empty_terminal_output(self):
        item = {"type": "message", "content": [{"type": "output_text", "text": '{"ok":true}'}]}
        response = await completed_response(stream(
            {"type": "response.output_item.done", "output_index": 0, "item": item},
            {"type": "response.completed", "response": {"id": "resp_1", "status": "completed", "output": []}},
        ))
        self.assertEqual(chat_response(response)["choices"][0]["message"]["content"], '{"ok":true}')

    async def test_final_item_without_terminal_completion_is_rejected(self):
        with self.assertRaises(web.HTTPBadGateway):
            await completed_response(stream({"type": "response.output_item.done", "output_index": 0,
                                             "item": {"type": "message", "content": []}}))

    async def test_completed_output_over_budget_is_rejected(self):
        with self.assertRaises(web.HTTPBadGateway):
            await completed_response(stream({"type": "response.completed", "response": {
                "status": "completed", "usage": {"output_tokens": 3000}}}), max_output_tokens=2048)

    async def test_usage_limit_after_streaming_is_reported(self):
        with self.assertRaises(web.HTTPTooManyRequests):
            await completed_response(stream({"type": "response.failed", "response": {
                "error": {"code": "subscription_sharing_usage_limit_exceeded"}}}))

    async def test_incomplete_response_rejected(self):
        with self.assertRaises(web.HTTPBadGateway):
            await completed_response(stream({"type": "response.incomplete"}))

    async def test_top_level_plan_usage_error_is_reported(self):
        with self.assertRaises(web.HTTPTooManyRequests):
            await completed_response(stream({"type": "error", "code": "subscription_sharing_usage_unavailable"}))

    async def test_concurrent_refresh_happens_once(self):
        with tempfile.TemporaryDirectory() as directory:
            credentials = Path(directory) / "credentials.json"
            save_credentials(credentials, {"scopes": ["chatgpt.tokens.use.direct"], "expires_at": 0,
                                           "client_id": "issued-client", "refresh_token": "old-refresh"})
            exchanges = []

            async def exchange(session, fields):
                exchanges.append(fields)
                await asyncio.sleep(0.01)
                return {"access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600}

            client = PlanClient(credentials, None)
            with patch("openai_plan.exchange", exchange):
                self.assertEqual(await asyncio.gather(*(client.access_token() for _ in range(8))), ["new-access"] * 8)
            self.assertEqual(len(exchanges), 1)
            self.assertEqual(json.loads(credentials.read_text())["refresh_token"], "new-refresh")
            self.assertEqual(credentials.stat().st_mode & 0o777, 0o600)

    async def test_missing_credentials_fail_closed(self):
        with self.assertRaises(web.HTTPServiceUnavailable):
            await PlanClient("/nonexistent/credentials.json", None).access_token()

    async def test_auth_required_before_any_upstream_request(self):
        async with ClientSession() as session:
            async with TestClient(TestServer(application("/nonexistent/credentials.json", "private-key", session))) as client:
                response = await client.post("/v1/chat/completions", json={})
                self.assertEqual(response.status, 401)

    async def test_authenticated_request_without_subscription_is_unavailable(self):
        async with ClientSession() as session:
            async with TestClient(TestServer(application("/nonexistent/credentials.json", "private-key", session))) as client:
                response = await client.post("/v1/chat/completions", headers={"Authorization": "Bearer private-key"},
                                             json={"model": MODEL, "messages": [{"role": "user", "content": "test"}]})
                self.assertEqual(response.status, 503)


class TranslationTests(unittest.TestCase):
    def test_request_must_be_a_json_object(self):
        with self.assertRaises(web.HTTPBadRequest):
            responses_request([])

    def test_schema_preserved_and_unsupported_token_limit_omitted(self):
        schema = {"name": "graph", "strict": True, "schema": {"type": "object", "properties": {}}}
        request = responses_request({"model": MODEL, "messages": [{"role": "system", "content": "extract"}],
                                     "response_format": {"type": "json_schema", "json_schema": schema},
                                     "max_completion_tokens": 2048})
        self.assertEqual(request["text"]["format"], {"type": "json_schema", **schema})
        self.assertNotIn("max_output_tokens", request)
        self.assertIs(request["store"], False)
        self.assertIs(request["stream"], True)

    def test_model_cannot_be_substituted(self):
        with self.assertRaises(web.HTTPBadRequest):
            responses_request({"model": "another-model"})

    def test_multimodal_input_rejected(self):
        with self.assertRaises(web.HTTPBadRequest):
            responses_request({"model": MODEL, "messages": [{"role": "user", "content": []}]})

    def test_missing_subscription_scope_rejected(self):
        with self.assertRaises(RuntimeError):
            token_record({"expires_in": 3600, "scope": "openid"}, {})

    def test_refusal_is_not_ingested_as_memory(self):
        with self.assertRaises(web.HTTPBadGateway):
            chat_response({"id": "resp_1", "output": [{"type": "message", "content": [{"type": "refusal"}]}]})


if __name__ == "__main__":
    unittest.main()
