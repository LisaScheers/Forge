"""Check that the gateway answers and still serves the models its clients use.

Usage: gateway_probe.py BASE_URL KEY_FILE MODEL...
Exits 0 when every MODEL is listed, 1 when the gateway answers but lacks some,
and 2 when it cannot be reached or refuses the key, so a monitor can tell an
outage from a model that disappeared upstream.
"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def listed_models(base_url, key, timeout=15):
    request = urllib.request.Request(base_url.rstrip("/") + "/v1/models",
                                     headers={"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return {model["id"] for model in json.load(response)["data"]}


def probe(base_url, key, expected):
    try:
        listed = listed_models(base_url, key)
    except (urllib.error.URLError, OSError, ValueError, KeyError) as error:
        if isinstance(error, urllib.error.HTTPError):
            error.close()
        return 2, f"gateway unreachable or refused the key: {error}"
    missing = sorted(set(expected) - listed)
    if missing:
        return 1, "gateway answers but lacks: " + ", ".join(missing)
    return 0, f"gateway answers and lists all {len(expected)} expected models"


def main():
    try:
        key = Path(sys.argv[2]).read_text(encoding="utf-8").strip()
    except OSError as error:
        print(f"cannot read the gateway key: {error}", file=sys.stderr)
        sys.exit(2)
    status, message = probe(sys.argv[1], key, sys.argv[3:])
    print(message, file=sys.stderr if status else sys.stdout)
    sys.exit(status)


if __name__ == "__main__":
    main()
