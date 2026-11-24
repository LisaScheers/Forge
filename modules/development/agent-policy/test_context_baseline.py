import json
import tempfile
import unittest
from pathlib import Path

from context_baseline import claude_probe_input, codex_probe_input, layers, report


class ContextBaselineTests(unittest.TestCase):
    def test_first_requests_of_both_clients_are_summarised(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        home = Path(directory.name)
        claude = home / ".claude" / "projects" / "repo"
        claude.mkdir(parents=True)
        for name, cache in [("a", 20000), ("b", 30000)]:
            events = [
                {"type": "user", "message": {"content": "hi"}},
                # A subagent's reply is not the session's start.
                {"type": "assistant", "isSidechain": True, "message": {"usage": {"input_tokens": 999999}}},
                {"type": "assistant", "message": {"usage": {"input_tokens": 2, "cache_creation_input_tokens": cache,
                                                            "cache_read_input_tokens": 1000}}},
                {"type": "assistant", "message": {"usage": {"input_tokens": 5, "cache_read_input_tokens": 90000}}},
            ]
            (claude / f"{name}.jsonl").write_text("\n".join(json.dumps(event) for event in events) + "\nnot json\n")
        codex = home / ".codex" / "sessions" / "2026" / "11" / "23"
        codex.mkdir(parents=True)
        (codex / "rollout.jsonl").write_text("\n".join(json.dumps(event) for event in [
            {"payload": {"type": "session_meta"}},
            {"payload": {"type": "token_count", "info": None}},
            {"payload": {"type": "token_count", "info": {"last_token_usage": {"input_tokens": 23222}}}},
            {"payload": {"type": "token_count", "info": {"last_token_usage": {"input_tokens": 50000}}}},
        ]))
        result = report(home, days=7)
        self.assertEqual(result["claude"], {"sessions": 2, "median": 26002, "min": 21002, "max": 31002})
        self.assertEqual(result["codex"], {"sessions": 1, "median": 23222, "min": 23222, "max": 23222})

    def test_probe_outputs_are_read(self):
        claude = json.dumps({"result": "OK", "usage": {"input_tokens": 2, "cache_creation_input_tokens": 25727,
                                                       "cache_read_input_tokens": 24222, "output_tokens": 4}})
        self.assertEqual(claude_probe_input(claude), 49951)
        codex = "\n".join([json.dumps({"type": "thread.started"}), "warning: not json",
                           json.dumps({"type": "turn.completed", "usage": {"input_tokens": 25077}})])
        self.assertEqual(codex_probe_input(codex), 25077)
        with self.assertRaises(ValueError):
            codex_probe_input(json.dumps({"type": "turn.failed"}))

    def test_layers_change_only_what_they_leave_out(self):
        probes = layers(["cognee", "rea"])
        command, _ = probes["codex without MCP"]
        self.assertEqual(command[:6], ["codex", "exec", "-c", "mcp_servers.cognee.enabled=false",
                                       "-c", "mcp_servers.rea.enabled=false"])
        self.assertIn("--strict-mcp-config", probes["claude without MCP or skills"][0])
        self.assertIn("--disable-slash-commands", probes["claude without MCP or skills"][0])

    def test_no_sessions(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.assertEqual(report(Path(directory.name), days=7), {"claude": None, "codex": None})


if __name__ == "__main__":
    unittest.main()
