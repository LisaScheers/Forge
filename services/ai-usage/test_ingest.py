import base64
import io
import json
import os
from pathlib import Path
import tempfile
import time
import unittest

from ingest import archive, collect, observations, token_leaves
from render_proxy import render


class Destination:
    def __init__(self):
        self.rows = {}

    def insert(self, table, rows):
        self.rows.setdefault(table, []).extend(rows)


def transcript(response):
    return ("=== REQUEST INFO ===\nURL: /v1/responses\n"
            "=== REQUEST BODY ===\n{\"input\":\"secret prompt 🦊\"}\n"
            "=== API RESPONSE 1 ===\nBody:\n"
            f"data: {json.dumps(response)}\n\n"
            "=== RESPONSE ===\n"
            f"data: {json.dumps(response)}\n")


class IngestTests(unittest.TestCase):
    def test_preserves_every_reported_category_and_excludes_booleans(self):
        usage = {"input_tokens": 17, "input_tokens_details": {"cached_tokens": 8, "audio_tokens": 3},
                 "output_tokens": 9, "output_tokens_details": {"reasoning_tokens": 5},
                 "new_category": [{"count": 4}], "estimated": True}
        self.assertEqual(token_leaves(usage), {
            "input_tokens": 17, "input_tokens_details.cached_tokens": 8,
            "input_tokens_details.audio_tokens": 3, "output_tokens": 9,
            "output_tokens_details.reasoning_tokens": 5, "new_category.0.count": 4,
        })

    def test_upstream_only_preserves_raw_usage_and_failed_responses(self):
        response = {"type": "response.incomplete", "response": {
            "id": "resp_1", "model": "test", "usage": {"output_tokens": 42, "future": "kept"}}}
        rows = list(observations(io.StringIO(transcript(response))))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["response_key"], "resp_1")
        self.assertEqual(json.loads(rows[0]["usage_json"])["future"], "kept")

    def test_websocket_and_anthropic_partial_usage(self):
        events = [
            {"type": "message_start", "message": {"id": "msg_1", "model": "claude", "usage": {"input_tokens": 12}}},
            {"type": "message_delta", "usage": {"output_tokens": 7}},
        ]
        text = "=== API WEBSOCKET TIMELINE ===\n" + "\n".join(map(json.dumps, events))
        rows = list(observations(io.StringIO(text)))
        self.assertEqual([r["response_key"] for r in rows], ["msg_1", "msg_1"])
        self.assertEqual(rows[1]["tokens"], {"output_tokens": 7})

    def test_tool_model_tokens_are_preserved_alongside_primary_usage(self):
        response = {"type": "response.completed", "response": {
            "id": "resp_tools", "usage": {"input_tokens": 12, "output_tokens": 7},
            "tool_usage": {"image_gen": {"input_tokens": 30, "output_tokens": 40}}}}
        rows = list(observations(io.StringIO(transcript(response))))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1]["tokens"], {
            "tool_usage.image_gen.input_tokens": 30, "tool_usage.image_gen.output_tokens": 40})

    def test_retries_without_response_ids_keep_separate_attempts(self):
        text = ('=== API RESPONSE 1 ===\n{"usage":{"output_tokens":1}}\n'
                '=== API RESPONSE 2 ===\n{"usage":{"output_tokens":2}}\n')
        rows = list(observations(io.StringIO(text)))
        self.assertNotEqual(rows[0]["response_key"], rows[1]["response_key"])

    def test_large_unicode_capture_is_byte_exact_and_manifest_last(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "responses-test.log"
            data = ("=== REQUEST INFO ===\n" + "🦊" * 600000).encode()
            log.write_bytes(data)
            destination = Destination()
            archive(log, log.name, destination)
            reconstructed = b"".join(base64.b64decode(r["content_b64"]) for r in destination.rows["chunks"])
            self.assertEqual(reconstructed, data)
            self.assertEqual(list(destination.rows)[-1], "files")
            self.assertEqual(destination.rows["files"][0]["bytes"], len(data))

    def test_failed_upload_does_not_advance_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "arbitrary-route.log"
            log.write_text(transcript({"usage": {"input_tokens": 10}}))
            os.utime(log, (time.time() - 10, time.time() - 10))
            failed = Destination()
            def fail(table, rows):
                raise OSError("offline")
            failed.insert = fail
            with self.assertRaises(OSError):
                collect(root, root / "state.sqlite", failed)
            destination = Destination()
            collect(root, root / "state.sqlite", destination)
            self.assertEqual(len(destination.rows["files"]), 1)
            collect(root, root / "state.sqlite", destination)
            self.assertEqual(len(destination.rows["files"]), 1)

    def test_mutating_log_never_commits_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "test.log"
            log.write_text(transcript({"usage": {"input_tokens": 10}}))
            destination = Destination()
            original = destination.insert
            mutated = False
            def mutate(table, rows):
                nonlocal mutated
                original(table, rows)
                if table == "chunks" and not mutated:
                    mutated = True
                    with log.open("a") as target:
                        target.write("changed\n")
            destination.insert = mutate
            with self.assertRaises(RuntimeError):
                archive(log, log.name, destination)
            self.assertNotIn("files", destination.rows)

    def test_seed_never_overwrites_refreshed_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            credentials = root / "credentials"
            credentials.mkdir()
            for name, value in [("client-key", "client-secret"), ("openrouter-key", "provider-secret"),
                                ("codex-auth", '{"access_token":"initial"}')]:
                (credentials / name).write_text(value)
            template = root / "template.json"
            template.write_text(json.dumps({"auth-dir": str(root / "auth"), "openai-compatibility": [{}]}))
            destination = root / "config.yaml"
            render(template, credentials, destination)
            auth = root / "auth/codex.json"
            auth.write_text('{"access_token":"refreshed"}')
            render(template, credentials, destination)
            self.assertEqual(json.loads(auth.read_text())["access_token"], "refreshed")
            self.assertIs(json.loads(auth.read_text())["websockets"], True)
            self.assertEqual(destination.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
