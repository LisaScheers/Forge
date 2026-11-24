"""aurora-control --directory DIR TOOL: one request, JSON arguments on stdin.

Prints the reply envelope. Exit status 0 for a result, 1 for an error reply,
2 when no viewer with the bridge listens at DIR or the input is invalid.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import viewer_api


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="aurora-control", description=__doc__.splitlines()[0])
    parser.add_argument("--directory", type=Path, default=viewer_api.default_directory(), help=f"the viewer's {viewer_api.ENV}")
    parser.add_argument("--request-id", help="an id to find this command's receipt and events later")
    parser.add_argument("--timeout", type=float, default=viewer_api.DEFAULT_TIMEOUT)
    parser.add_argument("tool", help="viewer_state, viewer_query, … (see tools.json)")
    args = parser.parse_args(argv)
    if args.directory is None or not args.directory.is_absolute():
        parser.error(f"--directory (or {viewer_api.ENV}) must be an absolute path")
    text = sys.stdin.read() if not sys.stdin.isatty() else ""
    try:
        arguments = json.loads(text) if text.strip() else {}
    except json.JSONDecodeError as error:
        print(f"aurora-control: stdin is not JSON: {error}", file=sys.stderr)
        return 2
    if not isinstance(arguments, dict):
        print("aurora-control: stdin must hold a JSON object", file=sys.stderr)
        return 2
    try:
        answer = viewer_api.request(args.directory, args.tool, arguments, args.request_id, args.timeout)
    except viewer_api.ViewerUnavailable as error:
        print(f"aurora-control: {error}", file=sys.stderr)
        return 2
    print(json.dumps(answer, indent=2))
    return 1 if "error" in answer else 0


if __name__ == "__main__":
    sys.exit(main())
