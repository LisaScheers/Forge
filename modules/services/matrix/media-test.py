import hashlib
import json
from pathlib import Path
import sys
from urllib.request import Request, urlopen

BASE = "http://127.0.0.1:8008"
STATE = Path("/run/matrix-media-test.json")


def request(endpoint, data=None, token=None, content_type="application/json", raw=False):
    headers = {"Content-Type": content_type}
    if token:
        headers["Authorization"] = "Bearer " + token
    with urlopen(Request(BASE + endpoint, data=data, headers=headers), timeout=120) as response:
        return response.read() if raw else json.load(response)


if sys.argv[1] == "upload":
    account = request("/_matrix/client/v3/register", json.dumps({
        "username": "media-test", "password": "isolated-test-only",
        "auth": {"type": "m.login.dummy"},
    }).encode())
    token = account["access_token"]
    limits = request("/_matrix/client/v1/media/config", token=token)
    assert limits["m.upload.size"] == 512 * 1024 * 1024
    # Cross the old 50 MiB limit and exercise real Synapse writes to NFS.
    payload = bytes(51 * 1024 * 1024)
    uploaded = request("/_matrix/media/v3/upload?filename=storage-test.bin", payload,
                       token=token, content_type="application/octet-stream")
    STATE.write_text(json.dumps({"token": token, "mxc": uploaded["content_uri"],
                                 "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)}))

state = json.loads(STATE.read_text())
data = request("/_matrix/client/v1/media/download/" + state["mxc"].removeprefix("mxc://"),
               token=state["token"], raw=True)
assert len(data) == state["bytes"] and hashlib.sha256(data).hexdigest() == state["sha256"]
print("Uploaded media bytes and URL remain intact")
