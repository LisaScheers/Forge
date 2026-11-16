"""Import native Codex capture bundles without replaying their diagnostic graph."""

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import time

from ingest import ClickHouse, archive


def payload(bundle, reference):
    relative = Path(reference["path"])
    target = (bundle / relative).resolve()
    if relative.is_absolute() or not target.is_relative_to(bundle.resolve()):
        raise ValueError("Native payload escapes its bundle")
    return target.read_text(encoding="utf-8")


def captures(bundle, now=None):
    manifest = json.loads((bundle / "manifest.json").read_text())
    if manifest["schema_version"] != 2:
        raise ValueError("Unsupported native capture schema; keep the recording client pinned")
    attempts = {}
    previous = 0
    closed = False
    with (bundle / "trace.jsonl").open() as source:
        for line in source:
            # A running recorder may not have flushed the final record yet.
            if not line.endswith("\n"):
                break
            event = json.loads(line)
            if event["schema_version"] != 2 or event["seq"] != previous + 1:
                raise ValueError("Invalid native capture event sequence")
            previous = event["seq"]
            item = event["payload"]
            kind = item["type"]
            if kind == "recording_completed":
                closed = True
            if kind == "inference_started":
                identity = item["inference_call_id"]
                if identity in attempts:
                    raise ValueError("Repeated native inference identity")
                attempts[identity] = {"start": event, "responses": [], "terminal": None}
            elif kind == "other" and item.get("kind") == "raw_response":
                identity = item["metadata"]["inference_call_id"]
                attempts[identity]["responses"].extend(item["payloads"])
            elif kind in {"inference_completed", "inference_failed", "inference_cancelled"}:
                attempts[item["inference_call_id"]]["terminal"] = event

    for identity, attempt in attempts.items():
        terminal = attempt["terminal"]
        if terminal is None:
            stale = (time.time() if now is None else now) - (bundle / "trace.jsonl").stat().st_mtime > 300
            if not closed and not stale:
                continue
            terminal = {"payload": {"type": "inference_failed", "error": "Capture ended without a terminal record"}}
        start = attempt["start"]
        item = start["payload"]
        request = payload(bundle, item["request_payload"])
        responses = [json.loads(payload(bundle, ref))["data"] for ref in attempt["responses"]]
        completed = terminal["payload"]["type"] == "inference_completed"
        def terminal_response(data):
            try:
                return json.loads(data).get("type") in {"response.completed", "response.done"}
            except (ValueError, AttributeError):
                return False
        if completed and not any(terminal_response(data) for data in responses):
            raise ValueError("Completed native capture lacks original response JSON; use the patched client")
        timestamp = datetime.fromtimestamp(start["wall_time_unix_ms"] / 1000, timezone.utc).isoformat()
        # Retain the original request and response JSON strings, including fields
        # Codex does not recognize. Both existing archive readers understand this envelope.
        info = ("=== REQUEST INFO ===\n"
                f"Timestamp: {timestamp}\nURL: native://codex/responses\n"
                f"Session-Id: {start['thread_id']}\n"
                f"Inference-Id: {identity}\nCapture-Source: codex-native-v2\n"
                "=== HEADERS ===\nUser-Agent: codex-native-capture\n"
                f"=== REQUEST BODY ===\n{request}\n")
        # The downstream and upstream projections share original JSON data;
        # usage ingestion reads only the upstream section and never counts both.
        def framed(data):
            try:
                json.loads(data)
            except ValueError:
                # Keep undecodable upstream data recoverable without letting it
                # consume the following valid event in the archive's JSON parser.
                data = json.dumps({"type": "codex.capture.unparsed", "data": data})
            return "data: " + data.replace("\n", "\ndata: ")
        body = "\n".join(framed(data) for data in responses)
        if not completed:
            body += "\n" + json.dumps({"type": "error", "error": terminal["payload"].get("error", "Inference interrupted")})
        text = info + f"=== API RESPONSE 1 ===\n{body}\n=== RESPONSE ===\n{body}\n"
        yield manifest["rollout_id"], identity, text.encode()


def collect_native(root, state_dir, destination):
    state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    with closing(sqlite3.connect(state_dir / "native.sqlite")) as state:
        state.execute("CREATE TABLE IF NOT EXISTS attempts (name TEXT PRIMARY KEY, digest TEXT NOT NULL)")
        state.execute("CREATE TABLE IF NOT EXISTS bundles (name TEXT PRIMARY KEY, signature TEXT NOT NULL)")
        for manifest in sorted(root.glob("*/trace-*/manifest.json")):
            bundle = manifest.parent
            host = bundle.parent.name
            try:
                metadata = manifest.stat()
                trace = (bundle / "trace.jsonl").stat()
                # Payload files are immutable. Revisit an unchanged active bundle
                # once it becomes stale, so a crashed attempt still gets archived.
                signature = repr((metadata.st_size, metadata.st_mtime_ns, trace.st_size,
                                  trace.st_mtime_ns, time.time() - trace.st_mtime > 300))
                bundle_name = str(bundle.relative_to(root))
                if state.execute("SELECT signature FROM bundles WHERE name=?", (bundle_name,)).fetchone() == (signature,):
                    continue
                for rollout, identity, data in captures(bundle):
                    name = f"codex/{host}/{rollout}/{identity}.log"
                    digest = hashlib.sha256(data).hexdigest()
                    if state.execute("SELECT digest FROM attempts WHERE name=?", (name,)).fetchone() == (digest,):
                        continue
                    # archive() checkpoints its manifest last; only acknowledge
                    # this upload after every ClickHouse write has succeeded.
                    with tempfile.TemporaryDirectory(dir=state_dir) as directory:
                        staged = Path(directory) / "capture.log"
                        staged.write_bytes(data)
                        archive(staged, name, destination)
                    state.execute("INSERT OR REPLACE INTO attempts VALUES (?,?)", (name, digest))
                    state.commit()
                state.execute("INSERT OR REPLACE INTO bundles VALUES (?,?)", (bundle_name, signature))
                state.commit()
            except FileNotFoundError:
                # rsync can publish the event log before its referenced payloads.
                # Leave the checkpoint untouched and retry on the next run.
                continue


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--incoming", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    collect_native(args.incoming, args.state, ClickHouse())


if __name__ == "__main__":
    main()
