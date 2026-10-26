"""Exercise missing-thumbnail recovery with real Synapse and loopback only."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
from urllib.request import ProxyHandler, Request, build_opener
import zlib

interfaces = {line.split(":", 1)[0].strip() for line in Path("/proc/net/dev").read_text().splitlines()[2:]}
assert interfaces == {"lo"}, interfaces
opener = build_opener(ProxyHandler({}))


def request(endpoint, payload=None, token=None, content_type="application/json", raw=False):
    headers = {"Content-Type": content_type}
    if token:
        headers["Authorization"] = "Bearer " + token
    with opener.open(Request("http://127.0.0.1:8008" + endpoint, data=payload, headers=headers), timeout=60) as response:
        return response.read() if raw else json.load(response)


account = request("/_matrix/client/v3/register", json.dumps({
    "username": "thumbnail-test", "password": "isolated-test-only",
    "auth": {"type": "m.login.dummy"},
}).encode())
token = account["access_token"]


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


pixels = b"".join(b"\0" + bytes([row, 96, 192]) * 64 for row in range(64))
image = (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 64, 64, 8, 2, 0, 0, 0))
         + png_chunk(b"IDAT", zlib.compress(pixels)) + png_chunk(b"IEND", b""))
uploaded = request("/_matrix/media/v3/upload?filename=original.png", image, token, "image/png")
mxc = uploaded["content_uri"].removeprefix("mxc://")
media_id = mxc.split("/", 1)[1]
endpoint = "/_matrix/client/v1/media/thumbnail/" + mxc + "?width=32&height=32&method=scale"
before = request(endpoint, token=token, raw=True)
assert before
media = Path("/var/lib/matrix-synapse/media_store")
original = media / "local_content" / media_id[:2] / media_id[2:4] / media_id[4:]
original_sha256 = hashlib.sha256(original.read_bytes()).hexdigest()
assert original.read_bytes() == image
cache = media / "local_thumbnails"
assert any(entry.is_file() for entry in cache.rglob("*"))
shutil.rmtree(cache)
assert not cache.exists()
after = request(endpoint, token=token, raw=True)
assert after == before
assert any(entry.is_file() for entry in cache.rglob("*"))
assert hashlib.sha256(original.read_bytes()).hexdigest() == original_sha256
assert request("/_matrix/client/v1/media/download/" + mxc, token=token, raw=True) == image
print("Authenticated thumbnail regenerated without external network; original bytes unchanged")
