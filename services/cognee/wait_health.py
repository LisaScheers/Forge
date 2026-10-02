"""Gate systemd startup on HTTP readiness without failing Podman timer units."""

import sys
import time
import urllib.error
import urllib.request

deadline = time.monotonic() + 240
while time.monotonic() < deadline:
    try:
        request = urllib.request.Request(
            f"http://127.0.0.1:{int(sys.argv[1])}/health",
            headers={"Host": "cognee.local.bylisa.dev"},
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            if response.status == 200:
                break
    except (urllib.error.URLError, TimeoutError):
        pass
    time.sleep(2)
else:
    raise SystemExit("Cognee HTTP readiness timed out")
