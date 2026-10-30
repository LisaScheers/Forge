"""Protect app-owned settings when Home Manager refreshes MCP registrations."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import tomlkit


class SyncMcpConfigTest(unittest.TestCase):
    def test_rejects_incomplete_defaults_without_changing_live_config(self):
        with tempfile.TemporaryDirectory() as directory:
            config_file = Path(directory) / "config.toml"
            defaults_file = Path(directory) / "defaults.toml"
            original = '# App-owned choices\nmodel = "my-model"\n'
            config_file.write_text(original)
            defaults_file.write_text("[mcp_servers.rea]\nstartup_timeout_sec = 30\n")
            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("sync-mcp-config.py")),
                 str(config_file), str(defaults_file), "rea"],
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no command or URL", result.stderr)
            self.assertEqual(config_file.read_text(), original)

    def test_preserves_unmanaged_settings_and_removes_disabled_server(self):
        with tempfile.TemporaryDirectory() as directory:
            config_file = Path(directory) / "config.toml"
            defaults_file = Path(directory) / "defaults.toml"
            config_file.write_text('''# App-owned choices
model = "my-model"
[mcp_servers.manual]
url = "https://example.com/mcp"
[mcp_servers.cognee]
url = "https://old.example.com/mcp"
[mcp_servers.rea]
command = "/old/rea"
args = ["mcp"]
''')
            defaults_file.write_text('''model = "default-model"
[mcp_servers.cognee]
url = "https://new.example.com/mcp"
[mcp_servers.rea]
command = "/nix/store/new-rea/bin/rea"
args = ["mcp"]
''')

            def sync(*names):
                subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("sync-mcp-config.py")),
                     str(config_file), str(defaults_file), *names],
                    check=True,
                )

            sync("rea")
            document = tomlkit.parse(config_file.read_text())
            self.assertEqual(document["model"], "my-model")
            self.assertIn("# App-owned choices", config_file.read_text())
            self.assertEqual(document["mcp_servers"]["manual"]["url"], "https://example.com/mcp")
            self.assertEqual(document["mcp_servers"]["cognee"]["url"], "https://old.example.com/mcp")
            self.assertEqual(document["mcp_servers"]["rea"]["command"], "/nix/store/new-rea/bin/rea")
            before = config_file.stat().st_mtime_ns
            sync("rea")
            self.assertEqual(config_file.stat().st_mtime_ns, before)

            defaults_file.write_text("[mcp_servers.cognee]\nurl = 'https://new.example.com/mcp'\n")
            sync("cognee", "rea")
            document = tomlkit.parse(config_file.read_text())
            self.assertNotIn("rea", document["mcp_servers"])
            self.assertEqual(document["mcp_servers"]["cognee"]["url"], "https://new.example.com/mcp")
            self.assertEqual(document["mcp_servers"]["manual"]["url"], "https://example.com/mcp")


if __name__ == "__main__":
    unittest.main()
