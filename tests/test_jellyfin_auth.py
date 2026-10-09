import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET


def load_helper(name):
    source = Path(__file__).resolve().parents[1] / "services/jellyfin-auth" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


configure = load_helper("configure").configure
link = load_helper("link")


class AccountLinks(unittest.TestCase):
    def setUp(self):
        self.users = [
            {"Id": user_id, "Name": name, "Policy": {
                "AuthenticationProviderId": link.LOCAL_PROVIDER,
                "IsAdministrator": name == "lisa",
                "EnableAllFolders": False,
                "EnabledFolders": ["movies"],
                "IsDisabled": False,
            }} for name, user_id in link.ACCOUNTS.items()
        ]
        self.users.append({"Id": "f35f8038-8cbe-4f2c-b31f-9dc14b927013", "Name": "jade"})
        self.writes = []
        self.missing_ldap = None

    def request(self, method, endpoint, body=None):
        if endpoint == "/Users":
            return copy.deepcopy(self.users)
        if endpoint == "/Ldap/LdapUserSearch":
            name = body["TestSearchUsername"]
            return {"LocatedDn": None if name == self.missing_ldap else f"cn={name},ou=users,dc=jellyfin,dc=bylisa,dc=dev"}
        user = next(user for user in self.users if user["Id"] == endpoint.split("/")[2])
        if method == "POST":
            self.writes.append((endpoint, body))
            user["Policy"] = copy.deepcopy(body)
        return copy.deepcopy(user)

    def test_links_only_selected_ids_preserving_all_other_policy_fields(self):
        original = copy.deepcopy(self.users)
        link.link_accounts(self.request)
        self.assertEqual(len(self.writes), 2)
        for before, after in zip(original[:2], self.users[:2]):
            expected = {**before["Policy"], "AuthenticationProviderId": link.LDAP_PROVIDER}
            self.assertEqual(after, {**before, "Policy": expected})
        self.assertEqual(self.users[2], original[2])
        link.link_accounts(self.request)
        self.assertEqual(len(self.writes), 2)

    def test_identity_mismatch_prevents_every_policy_change(self):
        self.users[1]["Name"] = "someone-else"
        with self.assertRaises(ValueError):
            link.link_accounts(self.request)
        self.assertEqual(self.writes, [])

    def test_missing_ldap_identity_prevents_every_policy_change(self):
        self.missing_ldap = "rose"
        with self.assertRaises(ValueError):
            link.link_accounts(self.request)
        self.assertEqual(self.writes, [])

    def test_unexpected_provider_prevents_every_policy_change(self):
        self.users[1]["Policy"]["AuthenticationProviderId"] = "other-provider"
        with self.assertRaises(ValueError):
            link.link_accounts(self.request)
        self.assertEqual(self.writes, [])


class Configuration(unittest.TestCase):
    def test_preserves_links_and_protects_credential(self):
        with tempfile.TemporaryDirectory() as directory:
            config_file = Path(directory) / "LDAP-Auth.xml"
            config_file.write_text("<PluginConfiguration><LdapUsers><LdapUser><LdapUid>stable-id</LdapUid></LdapUser></LdapUsers></PluginConfiguration>")
            configure(config_file, "secret<&>")
            root = ET.parse(config_file).getroot()
            self.assertEqual(root.findtext("LdapUsers/LdapUser/LdapUid"), "stable-id")
            self.assertEqual(root.findtext("LdapBindPassword"), "secret<&>")
            self.assertEqual(root.findtext("CreateUsersFromLdap"), "false")
            self.assertEqual(root.findtext("SkipSslVerify"), "false")
            self.assertEqual(root.findtext("LdapAdminFilter"), "_disabled_")
            self.assertEqual(config_file.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
