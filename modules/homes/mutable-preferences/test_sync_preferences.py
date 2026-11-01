import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("preferences", Path(__file__).with_name("sync-preferences.py"))
preferences = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preferences)


class PreferenceTests(unittest.TestCase):
    def test_json_preserves_secrets_and_unknown_provider_entries(self):
        current = {"providers": [{"id": "codex", "enabled": False, "tokenAccounts": {"token": "private"}}, {"id": "future", "enabled": True}], "safeStorage": {"account": "private"}}
        selected = {"providers": [{"id": "codex", "enabled": True}]}
        updated = json.loads(preferences.render(json.dumps(current), json.dumps(selected), "json"))
        self.assertTrue(updated["providers"][0]["enabled"])
        self.assertEqual(updated["providers"][0]["tokenAccounts"], {"token": "private"})
        self.assertEqual(updated["providers"][1], current["providers"][1])
        self.assertEqual(updated["safeStorage"], current["safeStorage"])

    def test_yaml_preserves_client_credentials(self):
        updated = preferences.render("client_secret: private\nenable_streaming: false\n", '{"enable_streaming": true}', "yaml")
        self.assertEqual(preferences.yaml.safe_load(updated), {"client_secret": "private", "enable_streaming": True})

    def test_llsd_preserves_unmanaged_keys(self):
        current = '<llsd><map><key>Theme</key><string>old</string><key>Login</key><string>private</string></map></llsd>'
        source = '<llsd><map><key>Theme</key><string>new</string></map></llsd>'
        updated = preferences.render(current, source, "llsd")
        values = {key.text: value.text for key, value in preferences.llsd_pairs(ET.fromstring(updated))}
        self.assertEqual(values, {"Theme": "new", "Login": "private"})

    def test_freecad_preserves_unmanaged_groups(self):
        current = '<FCParameters><FCParamGroup Name="Preferences"><FCInt Name="Size" Value="1"/><FCText Name="Recent">private</FCText></FCParamGroup></FCParameters>'
        source = '<FCParameters><FCParamGroup Name="Preferences"><FCInt Name="Size" Value="2"/></FCParamGroup></FCParameters>'
        root = ET.fromstring(preferences.render(current, source, "freecad"))
        self.assertEqual(root.find('.//FCInt').get('Value'), '2')
        self.assertEqual(root.find('.//FCText').text, 'private')

    def test_lines_preserve_machine_identity(self):
        updated = preferences.render("ad.anynet.pkey=private\nad.ui.lang=en\n", '{"ad.ui.lang": "nl"}', "lines")
        self.assertEqual(updated, "ad.anynet.pkey=private\nad.ui.lang=nl\n")

    def test_xml_layout_validates_before_replacement(self):
        self.assertEqual(preferences.render('<quickprefs/>', '<quickprefs><entries control_name="RenderFarClip"/></quickprefs>', 'xml'), '<quickprefs><entries control_name="RenderFarClip"/></quickprefs>')
        with self.assertRaises(ValueError):
            preferences.render('<unrelated/>', '<quickprefs/>', 'xml')

    def test_malformed_input_and_symlinks_are_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            source = home / "defaults.json"
            source.write_text('{"theme": "dark"}')
            target = home / "config.json"
            target.write_text("invalid")
            entry = {"target": "config.json", "source": str(source), "format": "json"}
            with self.assertRaises(ValueError):
                preferences.sync(home, entry)
            self.assertEqual(target.read_text(), "invalid")
            target.unlink()
            target.symlink_to(source)
            with self.assertRaises(ValueError):
                preferences.sync(home, entry)
            self.assertTrue(target.is_symlink())

    def test_sync_is_idempotent_private_and_writable(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            source = home / "defaults.json"
            source.write_text('{"theme": "dark"}')
            target = home / "config.json"
            target.write_text('{"theme": "light", "token": "private"}')
            entry = {"target": "config.json", "source": str(source), "format": "json"}
            preferences.sync(home, entry)
            self.assertEqual(json.loads(target.read_text()), {"theme": "dark", "token": "private"})
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            modified = target.stat().st_mtime_ns
            preferences.sync(home, entry)
            self.assertEqual(target.stat().st_mtime_ns, modified)


if __name__ == "__main__":
    unittest.main()
