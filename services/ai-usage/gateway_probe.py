"""Check that the gateway answers and still serves the models its clients use.

Usage: gateway_probe.py [--infer] BASE_URL KEY_FILE MODEL...
Exits 0 when every MODEL is listed, 1 when the gateway answers but lacks some,
and 2 when it cannot be reached or refuses the key, so a monitor can tell an
outage from a model that disappeared upstream. A listed model can still fail
upstream; --infer also asks each MODEL for one token, which costs a request per
model, and exits 1 when one does not answer.
"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def call(base_url, key, path, body=None, timeout=60):
    request = urllib.request.Request(
        base_url.rstrip("/") + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def answers(base_url, key, model):
    body = {"model": model, "max_tokens": 1, "messages": [{"role": "user", "content": "Reply with OK."}]}
    try:
        return bool(call(base_url, key, "/v1/chat/completions", body)["choices"])
    except (urllib.error.URLError, OSError, ValueError, KeyError) as error:
        if isinstance(error, urllib.error.HTTPError):
            error.close()
        return False


def probe(base_url, key, expected, infer=False):
    try:
        listed = {model["id"] for model in call(base_url, key, "/v1/models", timeout=15)["data"]}
    except (urllib.error.URLError, OSError, ValueError, KeyError) as error:
        if isinstance(error, urllib.error.HTTPError):
            error.close()
        return 2, f"gateway unreachable or refused the key: {error}"
    missing = sorted(set(expected) - listed)
    if missing:
        return 1, "gateway answers but lacks: " + ", ".join(missing)
    if infer:
        silent = [model for model in expected if not answers(base_url, key, model)]
        if silent:
            return 1, "gateway lists but gets no answer from: " + ", ".join(silent)
        return 0, f"gateway lists all {len(expected)} expected models and each answered"
    return 0, f"gateway answers and lists all {len(expected)} expected models"


def main():
    arguments = sys.argv[1:]
    infer = arguments[:1] == ["--infer"]
    if infer:
        arguments = arguments[1:]
    try:
        key = Path(arguments[1]).read_text(encoding="utf-8").strip()
    except OSError as error:
        print(f"cannot read the gateway key: {error}", file=sys.stderr)
        sys.exit(2)
    status, message = probe(arguments[0], key, arguments[2:], infer)
    print(message, file=sys.stderr if status else sys.stdout)
    sys.exit(status)


if __name__ == "__main__":
    main()
