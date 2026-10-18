import json
import os
from pathlib import Path
import re
import sys


secret_file, destination, domain = sys.argv[1:]
secrets = json.loads(Path(secret_file).read_text())
for name in ("as_token", "hs_token", "jwt_secret", "gatekeeper_secret", "avatar_proxy_key"):
    if not re.fullmatch(r"[a-f0-9]{64}", secrets[name]):
        raise ValueError("Invalid PluralMatrix credential format")
os.umask(0o077)
root = Path(destination)
registration = {
    "id": "sec-hive-pluralmatrix", "url": "http://127.0.0.1:29336",
    "as_token": secrets["as_token"], "hs_token": secrets["hs_token"],
    "sender_localpart": "plural_bot", "rate_limited": False,
    "namespaces": {"users": [{"exclusive": True, "regex": r"^@_plural_[a-z0-9_-]+:" + re.escape(domain) + "$"}], "aliases": [], "rooms": []},
    "de.sorunome.msc2409.push_ephemeral": True, "push_ephemeral": True,
    "org.matrix.msc3202": True,
}
for name, content, mode in (
    ("registration.yaml", json.dumps(registration), 0o640),
    ("environment", "\n".join(f"{key}={secrets[value]}" for key, value in (
        ("AS_TOKEN", "as_token"), ("JWT_SECRET", "jwt_secret"), ("GATEKEEPER_SECRET", "gatekeeper_secret"))) + "\n", 0o600),
    ("bridge-environment", "PLURALMATRIX_GATEKEEPER_SECRET=" + secrets["gatekeeper_secret"] + "\nPLURALMATRIX_AVATAR_PROXY_KEY=" + secrets["avatar_proxy_key"] + "\n", 0o600),
):
    temporary = root / (name + ".tmp")
    temporary.write_text(content + "\n")
    temporary.chmod(mode)
    temporary.replace(root / name)
