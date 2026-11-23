import json
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("retire_settings.py")


class RetireSettingsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.config = self.root / "config.toml"
        self.manifest = self.root / "state" / "codex-managed.json"

    def run_retire(self, declared, retired=()):
        (self.root / "declared.json").write_text(json.dumps(declared))
        (self.root / "retired.json").write_text(json.dumps(list(retired)))
        subprocess.run([sys.executable, "-B", SCRIPT, self.config, self.manifest,
                        self.root / "declared.json", self.root / "retired.json"], check=True)
        return tomllib.loads(self.config.read_text())

    def test_keys_declared_before_the_manifest_are_retired_by_name(self):
        self.config.write_text('sandbox_mode = "workspace-write"\n'
                               '[model_providers.nook]\nbase_url = "https://gateway"\n'
                               '[mcp_servers.node_repl]\ncommand = "node"\n')
        config = self.run_retire([["sandbox_mode"]], [["model_providers", "nook"]])
        self.assertNotIn("model_providers", config)
        self.assertEqual(config["mcp_servers"]["node_repl"]["command"], "node")
        self.assertEqual(config["sandbox_mode"], "workspace-write")
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_a_removed_declaration_leaves_the_file_next_time(self):
        self.config.write_text('[mcp_servers.webmcp]\ncommand = "webmcp"\n[mcp_servers.rea]\ncommand = "rea"\n'
                               '[mcp_servers.computer-use]\ncommand = "app"\n')
        self.run_retire([["mcp_servers", "webmcp"], ["mcp_servers", "rea"]])
        config = self.run_retire([["mcp_servers", "rea"]])
        self.assertEqual(sorted(config["mcp_servers"]), ["computer-use", "rea"])

    def test_json_settings_are_retired_too(self):
        self.config = self.root / "settings.json"
        self.config.write_text(json.dumps({"theme": "dark", "env": {"CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1",
                                                                    "ENABLE_TOOL_SEARCH": "true"}}))
        (self.root / "declared.json").write_text(json.dumps([["env", "ENABLE_TOOL_SEARCH"]]))
        (self.root / "retired.json").write_text(json.dumps([["env", "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB"]]))
        subprocess.run([sys.executable, "-B", SCRIPT, self.config, self.manifest,
                        self.root / "declared.json", self.root / "retired.json"], check=True)
        self.assertEqual(json.loads(self.config.read_text()), {"theme": "dark", "env": {"ENABLE_TOOL_SEARCH": "true"}})

    def test_an_unchanged_file_is_not_rewritten(self):
        self.config.write_text('# kept comment\nmodel = "x"\n')
        self.run_retire([["model"]], [["model_providers", "nook"]])
        self.assertIn("# kept comment", self.config.read_text())


if __name__ == "__main__":
    unittest.main()
