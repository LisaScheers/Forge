"""Report how much context Claude Code and Codex sessions start with.

The first model request of a session carries the system prompt, instructions,
skill descriptions and every tool schema loaded up front, before any work. Its
input size is the cost each new session pays, so this reads it from the session
files both clients already keep and summarises recent sessions per client.

Usage: context_baseline.py [HOME] [--days N]
"""

import argparse
import json
import statistics
import time
from pathlib import Path


def claude_first_input(path):
    """Prompt tokens of the main conversation's first reply, including cache."""
    with path.open(encoding="utf-8") as lines:
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            usage = (event.get("message") or {}).get("usage")
            if event.get("type") == "assistant" and usage and not event.get("isSidechain"):
                return (usage.get("input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)
                        + usage.get("cache_read_input_tokens", 0))
    return None


def codex_first_input(path):
    """Input tokens, cached ones included, of the first response in a rollout."""
    with path.open(encoding="utf-8") as lines:
        for line in lines:
            try:
                payload = json.loads(line).get("payload") or {}
            except json.JSONDecodeError:
                continue
            info = payload.get("info") if payload.get("type") == "token_count" else None
            if info and info.get("last_token_usage"):
                return info["last_token_usage"].get("input_tokens")
    return None


def summarise(files, first_input, since):
    sizes = [size for path in files if path.stat().st_mtime >= since
             for size in [first_input(path)] if size]
    if not sizes:
        return None
    return {"sessions": len(sizes), "median": int(statistics.median(sizes)), "min": min(sizes), "max": max(sizes)}


def report(home, days):
    since = time.time() - days * 86400
    return {
        "claude": summarise(list((home / ".claude" / "projects").glob("*/*.jsonl")), claude_first_input, since),
        "codex": summarise(list((home / ".codex" / "sessions").glob("*/*/*/*.jsonl")), codex_first_input, since),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("home", nargs="?", type=Path, default=Path.home())
    parser.add_argument("--days", type=float, default=7)
    arguments = parser.parse_args()
    for client, summary in report(arguments.home, arguments.days).items():
        if summary is None:
            print(f"{client}: no sessions in the last {arguments.days:g} days")
        else:
            print(f"{client}: {summary['sessions']} sessions, first request median {summary['median']:,} tokens "
                  f"(min {summary['min']:,}, max {summary['max']:,})")


if __name__ == "__main__":
    main()
