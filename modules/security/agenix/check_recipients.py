"""Check that each secret is encrypted for exactly the recipients its rule names.

Reads only the unencrypted age header, so it never decrypts anything. An SSH
stanza names its key by a short hash, so those are compared exactly; an X25519
stanza does not name its key, so only the number of age recipients is compared.

Usage: check_recipients.py RULES_JSON SECRETS_ROOT
"""

import base64
import hashlib
import json
import sys
from pathlib import Path


def ssh_tag(public_key: str) -> str:
    blob = base64.b64decode(public_key.split()[1])
    return base64.b64encode(hashlib.sha256(blob).digest()[:4]).decode().rstrip("=")


def header_stanzas(path: Path) -> list[list[str]]:
    data = path.read_bytes()
    # Some files use age's ASCII armor: base64 between BEGIN and END lines.
    if data.startswith(b"-----BEGIN AGE ENCRYPTED FILE-----"):
        body = [line for line in data.splitlines() if not line.startswith(b"-----")]
        data = base64.b64decode(b"".join(body))
    header = data.split(b"\n---", 1)[0].decode("ascii", "replace")
    return [line[3:].split() for line in header.splitlines() if line.startswith("-> ")]


def main() -> int:
    rules = json.loads(Path(sys.argv[1]).read_text())
    root = Path(sys.argv[2])
    problems = []
    for name, keys in sorted(rules.items()):
        if not (root / name).is_file():
            problems.append(f"{name}: no such file")
            continue
        stanzas = header_stanzas(root / name)
        want_ssh = sorted(ssh_tag(key) for key in keys if key.startswith("ssh-ed25519 "))
        have_ssh = sorted(stanza[1] for stanza in stanzas if stanza[0] == "ssh-ed25519")
        want_age = sum(key.startswith("age1") for key in keys)
        have_age = sum(stanza[0] == "X25519" for stanza in stanzas)
        if want_ssh != have_ssh or want_age != have_age:
            problems.append(f"{name}: encrypted recipients differ from its rule; run just secret-rekey")
    print("\n".join(problems) or f"{len(rules)} secrets match their rules")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
