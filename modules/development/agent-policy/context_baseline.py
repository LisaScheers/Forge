"""Report how much context Claude Code and Codex sessions start with.

The first model request of a session carries the system prompt, instructions,
skill descriptions and every tool schema loaded up front, before any work. Its
input size is the cost each new session pays, so this reads it from the session
files both clients already keep and summarises recent sessions per client.

With --probe it instead starts one short headless session per client in an
empty directory and reports that session's first request: a controlled
measurement that past sessions, with their varied working directories, are not.
--budget N then exits 1 when a probed client starts above N tokens. --layers
also probes each client with its configured MCP servers left out (and Claude with its skills
left out too), so the difference shows what each layer costs.

Usage: context_baseline.py [HOME] [--days N] | --probe [--layers] [--budget N]
"""

import argparse
import json
import os
import statistics
import subprocess
import tempfile
import time
import tomllib
from pathlib import Path

PROBE_PROMPT = "Reply with OK."


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


def recent_size(path, first_input, since):
    # A client may delete a session between the scan and the read.
    try:
        return first_input(path) if path.stat().st_mtime >= since else None
    except FileNotFoundError:
        return None


def summarise(files, first_input, since):
    sizes = [size for path in files for size in [recent_size(path, first_input, since)] if size]
    if not sizes:
        return None
    return {"sessions": len(sizes), "median": int(statistics.median(sizes)), "min": min(sizes), "max": max(sizes)}


def report(home, days):
    since = time.time() - days * 86400
    return {
        "claude": summarise(list((home / ".claude" / "projects").glob("*/*.jsonl")), claude_first_input, since),
        "codex": summarise(list((home / ".codex" / "sessions").glob("*/*/*/*.jsonl")), codex_first_input, since),
    }


def claude_probe_input(output):
    """First-request prompt tokens from `claude -p --output-format json`."""
    usage = json.loads(output)["usage"]
    return (usage.get("input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0))


def codex_probe_input(output):
    """Input tokens of the single turn from `codex exec --json`."""
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "turn.completed":
            return event["usage"]["input_tokens"]
    raise ValueError("codex exec reported no completed turn")


CLAUDE = ["claude", "-p", PROBE_PROMPT, "--output-format", "json"]
CODEX = ["codex", "exec", "--json", "--skip-git-repo-check", PROBE_PROMPT]
def codex_without(servers):
    """Codex merges `-c mcp_servers={}` into its config and keeps every server,
    so each configured server is switched off by name instead."""
    flags = [flag for name in servers for flag in ("-c", f"mcp_servers.{name}.enabled=false")]
    return CODEX[:2] + flags + CODEX[2:]


def layers(codex_servers):
    return {
        "claude without MCP": (CLAUDE + ["--strict-mcp-config"], claude_probe_input),
        "claude without MCP or skills": (CLAUDE + ["--strict-mcp-config", "--disable-slash-commands"],
                                         claude_probe_input),
        "codex without MCP": (codex_without(codex_servers), codex_probe_input),
    }


def configured_codex_servers():
    """The servers in Codex's config.toml. Plugin servers cannot be switched off with -c."""
    config = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "config.toml"
    try:
        return sorted((tomllib.loads(config.read_text(encoding="utf-8")).get("mcp_servers") or {}))
    except FileNotFoundError:
        return []


def probe(with_layers=False):
    commands = {"claude": (CLAUDE, claude_probe_input), "codex": (CODEX, codex_probe_input)}
    sizes = {}
    with tempfile.TemporaryDirectory() as empty:
        if with_layers:
            commands.update(layers(configured_codex_servers()))
        for client, (command, parse) in commands.items():
            result = subprocess.run(command, cwd=empty, stdin=subprocess.DEVNULL, capture_output=True,
                                    text=True, timeout=300, check=True)
            sizes[client] = parse(result.stdout)
    return sizes


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("home", nargs="?", type=Path, default=Path.home())
    parser.add_argument("--days", type=float, default=7)
    parser.add_argument("--probe", action="store_true", help="start one short session per client and measure it")
    parser.add_argument("--budget", type=int, help="with --probe, fail when a client starts above this many tokens")
    parser.add_argument("--layers", action="store_true", help="with --probe, also probe without MCP and skills")
    arguments = parser.parse_args()
    if arguments.probe:
        over = []
        for client, size in probe(arguments.layers).items():
            print(f"{client}: probe session's first request {size:,} tokens")
            if arguments.budget is not None and size > arguments.budget:
                over.append(client)
        if over:
            raise SystemExit(f"over the {arguments.budget:,}-token budget: {', '.join(over)}")
        return
    for client, summary in report(arguments.home, arguments.days).items():
        if summary is None:
            print(f"{client}: no sessions in the last {arguments.days:g} days")
        else:
            print(f"{client}: {summary['sessions']} sessions, first request median {summary['median']:,} tokens "
                  f"(min {summary['min']:,}, max {summary['max']:,})")


if __name__ == "__main__":
    main()
