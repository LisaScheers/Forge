import base64
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from codex_trace import captures, collect_native
from ingest import observations
from test_ingest import Destination


class NativeCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.incoming = self.root / "incoming"
        self.bundle = self.incoming / "vega" / "trace-test"
        (self.bundle / "payloads").mkdir(parents=True)
        (self.bundle / "manifest.json").write_text(json.dumps({"schema_version": 2, "rollout_id": "session"}))
        self.events = []
        self.request = {"model": "gpt-6.1-sol", "input": [
            {"role": "user", "content": "Native 🦊 prompt"},
            {"type": "configuration_update", "reasoning": {"effort": "high"}}]}
        self.response = {"type": "response.completed", "response": {
            "id": "response", "model": "gpt-6.1-sol", "output": [],
            "usage": {"input_tokens": 101, "input_tokens_details": {"cached_tokens": 40},
                      "output_tokens": 17, "output_tokens_details": {"reasoning_tokens": 5},
                      "total_tokens": 118, "future_tokens": 3},
            "tool_usage": {"image_gen": {"input_tokens": 9, "output_tokens": 10}}}}
        self.add("inference_started", inference_call_id="attempt", model="gpt-6.1-sol",
                 request_payload=self.write_payload(self.request))

    def write_payload(self, value):
        relative = "payloads/" + str(len(list((self.bundle / "payloads").iterdir()))) + ".json"
        (self.bundle / relative).write_text(json.dumps(value, ensure_ascii=False))
        return {"path": relative}

    def add(self, event_type, **fields):
        self.events.append({"schema_version": 2, "seq": len(self.events) + 1,
                            "thread_id": "session", "wall_time_unix_ms": 1794735500000,
                            "payload": {"type": event_type, **fields}})
        (self.bundle / "trace.jsonl").write_text("".join(json.dumps(e) + "\n" for e in self.events))

    def raw(self, value):
        data = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
        self.add("other", kind="raw_response", metadata={"inference_call_id": "attempt"},
                 payloads=[self.write_payload({"data": data})])

    def finish(self, kind="inference_completed"):
        self.add(kind, inference_call_id="attempt")

    def test_complete_content_future_fields_and_tool_tokens_survive(self):
        self.raw({"type": "response.output_text.delta", "delta": "🦊" * 300000})
        self.raw(self.response)
        self.finish()
        [(rollout, attempt, data)] = captures(self.bundle)
        self.assertEqual((rollout, attempt), ("session", "attempt"))
        text = data.decode()
        self.assertIn("configuration_update", text)
        self.assertIn("Native 🦊 prompt", text)
        self.assertIn("🦊" * 300000, text)
        rows = list(observations(text.splitlines()))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["tokens"]["future_tokens"], 3)
        self.assertEqual(rows[0]["tokens"]["input_tokens_details.cached_tokens"], 40)
        self.assertEqual(rows[1]["tokens"]["tool_usage.image_gen.output_tokens"], 10)

    def test_replay_is_idempotent_and_raw_bytes_are_recoverable(self):
        self.raw(self.response)
        self.finish()
        destination = Destination()
        collect_native(self.incoming, self.root / "state", destination)
        collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(len(destination.rows["files"]), 1)
        original = list(captures(self.bundle))[0][2]
        saved = b"".join(base64.b64decode(c["content_b64"]) for c in destination.rows["chunks"])
        self.assertEqual(original, saved)

    def test_failed_upload_can_be_retried_without_losing_usage(self):
        self.raw(self.response)
        self.finish()
        destination = Destination()
        def fail(table, rows):
            raise OSError("offline")
        destination.insert = fail
        with self.assertRaises(OSError):
            collect_native(self.incoming, self.root / "state", destination)
        destination = Destination()
        collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(len(destination.rows["files"]), 1)

    def test_unchanged_bundle_does_not_reread_payloads(self):
        self.raw(self.response)
        self.finish()
        destination = Destination()
        collect_native(self.incoming, self.root / "state", destination)
        with patch("codex_trace.captures", side_effect=AssertionError("reread unchanged bundle")):
            collect_native(self.incoming, self.root / "state", destination)
        self.add("recording_completed")
        with patch("codex_trace.captures", wraps=captures) as read:
            collect_native(self.incoming, self.root / "state", destination)
            self.assertEqual(read.call_count, 1)
        self.assertEqual(len(destination.rows["files"]), 1)

    def test_unchanged_active_bundle_is_revisited_after_crash_timeout(self):
        self.raw({"type": "response.output_text.delta", "delta": "before crash"})
        latest = (self.bundle / "trace.jsonl").stat().st_mtime
        destination = Destination()
        with patch("codex_trace.time.time", return_value=latest + 1):
            collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(destination.rows, {})
        with patch("codex_trace.time.time", return_value=latest + 301):
            collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(len(destination.rows["files"]), 1)

    def test_missing_payload_is_retried_after_transfer(self):
        self.raw(self.response)
        self.finish()
        saved = self.bundle / self.events[1]["payload"]["payloads"][0]["path"]
        data = saved.read_bytes()
        saved.unlink()
        destination = Destination()
        collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(destination.rows, {})
        saved.write_bytes(data)
        collect_native(self.incoming, self.root / "state", destination)
        self.assertEqual(len(destination.rows["files"]), 1)

    def test_normalized_capture_is_not_reported_as_complete(self):
        self.finish()
        with self.assertRaisesRegex(ValueError, "original response JSON"):
            list(captures(self.bundle))

    def test_interrupted_stream_retains_output_without_inventing_usage(self):
        self.raw({"type": "response.output_text.delta", "delta": "partial 🦊"})
        self.finish("inference_cancelled")
        data = list(captures(self.bundle))[0][2].decode()
        self.assertIn("partial 🦊", data)
        self.assertEqual(list(observations(data.splitlines())), [])

    def test_invalid_provider_data_does_not_hide_later_usage(self):
        self.raw('{"broken":')
        self.raw(self.response)
        self.finish()
        data = list(captures(self.bundle))[0][2].decode()
        self.assertIn('codex.capture.unparsed', data)
        self.assertEqual(list(observations(data.splitlines()))[0]["tokens"]["future_tokens"], 3)

    def test_inflight_capture_and_partial_last_record_wait(self):
        self.raw(self.response)
        self.assertEqual(list(captures(self.bundle)), [])
        self.finish()
        with (self.bundle / "trace.jsonl").open("a") as target:
            target.write('{"seq":4')
        self.assertEqual(len(list(captures(self.bundle))), 1)

    def test_closed_or_stale_capture_keeps_crash_evidence(self):
        self.raw({"type": "response.output_text.delta", "delta": "before crash"})
        latest = (self.bundle / "trace.jsonl").stat().st_mtime
        self.assertIn(b"before crash", list(captures(self.bundle, now=latest + 301))[0][2])
        self.add("recording_completed")
        self.assertIn(b"without a terminal record", list(captures(self.bundle))[0][2])

    def test_escaping_payload_and_unknown_schema_are_rejected(self):
        self.raw(self.response)
        self.finish()
        self.events[0]["payload"]["request_payload"]["path"] = "../outside.json"
        self.add("recording_completed")
        with self.assertRaisesRegex(ValueError, "escapes"):
            list(captures(self.bundle))
        (self.bundle / "manifest.json").write_text('{"schema_version":3}')
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            list(captures(self.bundle))


if __name__ == "__main__":
    unittest.main()
