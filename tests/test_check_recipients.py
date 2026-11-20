import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "modules/security/agenix/check_recipients.py"
HOST = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEHlf+pLT6XITnorOuDH0j9KtrVgZktsE5rPQzw3An8y"
USER = "age1" + "q" * 58


def tag(key):
    blob = base64.b64decode(key.split()[1])
    return base64.b64encode(hashlib.sha256(blob).digest()[:4]).decode().rstrip("=")


def encrypted(*stanzas, armor=False):
    lines = ["age-encryption.org/v1"]
    for stanza in stanzas:
        lines += [f"-> {stanza}", "Zm9v"]
    data = ("\n".join(lines) + "\n--- bWFj\n").encode() + b"\x00ciphertext\xff"
    if not armor:
        return data
    body = base64.b64encode(data).decode()
    wrapped = "\n".join(body[i:i + 64] for i in range(0, len(body), 64))
    return f"-----BEGIN AGE ENCRYPTED FILE-----\n{wrapped}\n-----END AGE ENCRYPTED FILE-----\n".encode()


class CheckRecipientsTest(unittest.TestCase):
    def check(self, files, rules):
        with tempfile.TemporaryDirectory() as root:
            for name, data in files.items():
                path = Path(root, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            rules_path = Path(root, "rules.json")
            rules_path.write_text(json.dumps(rules))
            return subprocess.run([sys.executable, "-I", str(SCRIPT), str(rules_path), root],
                                  text=True, capture_output=True)

    def test_matching_binary_and_armored_files_pass(self):
        for armor in (False, True):
            with self.subTest(armor=armor):
                result = self.check({"secrets/a/x.age": encrypted("X25519 e", f"ssh-ed25519 {tag(HOST)} s", armor=armor)},
                                    {"secrets/a/x.age": [USER, HOST]})
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_mismatches_fail(self):
        rule = {"secrets/a/x.age": [USER, HOST]}
        differ = "encrypted recipients differ"
        cases = {
            "extra RSA recipient": (encrypted("X25519 e", f"ssh-ed25519 {tag(HOST)} s", "ssh-rsa abcd s"), "unsupported recipient types ssh-rsa"),
            "extra age recipient": (encrypted("X25519 e", "X25519 f", f"ssh-ed25519 {tag(HOST)} s"), differ),
            "missing host": (encrypted("X25519 e"), differ),
            "other host": (encrypted("X25519 e", "ssh-ed25519 AAAAAA s"), differ),
        }
        for case, (data, reason) in cases.items():
            with self.subTest(case=case):
                result = self.check({"secrets/a/x.age": data}, rule)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(reason, result.stdout)

    def test_grease_stanzas_are_ignored(self):
        result = self.check({"secrets/a/x.age": encrypted("X25519 e", f"ssh-ed25519 {tag(HOST)} s", "x7-grease a b")},
                            {"secrets/a/x.age": [USER, HOST]})
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_rule_keys_of_unsupported_types_fail(self):
        result = self.check({"secrets/a/x.age": encrypted("X25519 e", f"ssh-ed25519 {tag(HOST)} s")},
                            {"secrets/a/x.age": [USER, HOST, "ssh-rsa AAAAB3NzaC1yc2E"]})
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsupported types", result.stdout)

    def test_a_rule_for_a_missing_file_is_reported(self):
        result = self.check({}, {"secrets/a/x.age": [USER, HOST]})
        self.assertEqual(result.returncode, 1)
        self.assertIn("no such file", result.stdout)


if __name__ == "__main__":
    unittest.main()
