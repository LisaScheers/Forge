"""Archive CLIProxy request logs byte-for-byte, with unabridged usage objects."""

import argparse
import base64
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import time
import urllib.parse
import urllib.request

CHUNK_SIZE = 1024 * 1024
SECTION = re.compile(r"^=== (.+?) ===$")


class ClickHouse:
    def __init__(self, url="http://127.0.0.1:8123"):
        self.url = url

    def query(self, query, data=b""):
        params = urllib.parse.urlencode({"query": query, "wait_end_of_query": "1"})
        request = urllib.request.Request(f"{self.url}/?{params}", data=data, headers={
            "X-ClickHouse-User": "default",
            "X-ClickHouse-Key": os.environ["AI_USAGE_CLICKHOUSE_PASSWORD"],
        })
        with urllib.request.urlopen(request, timeout=180) as response:
            result = response.read()
        # wait_end_of_query buffers query errors before HTTP headers are sent.
        return result

    def insert(self, table, rows):
        if rows:
            self.query(f"INSERT INTO ai_usage.{table} FORMAT JSONEachRow",
                       b"".join((json.dumps(row, ensure_ascii=True) + "\n").encode() for row in rows))


def token_leaves(value, prefix=""):
    result = {}
    if isinstance(value, dict):
        for key, child in value.items():
            result.update(token_leaves(child, f"{prefix}.{key}" if prefix else key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            result.update(token_leaves(child, f"{prefix}.{index}"))
    elif type(value) is int and 0 <= value < 2**64:
        result[prefix] = value
    return result


def usage_objects(record):
    if not isinstance(record, dict):
        return
    # These are envelope fields, not a recursive search through generated text.
    for key in ("usage", "usageMetadata"):
        if isinstance(record.get(key), dict):
            yield record[key]
    if isinstance(record.get("tool_usage"), dict):
        yield {"tool_usage": record["tool_usage"]}
    for key in ("response", "message"):
        yield from usage_objects(record.get(key))


def observations(lines):
    active, attempt, response_key, model = False, "", "", ""
    pending = ""
    ordinal = 0
    for line in lines:
        section = SECTION.match(line.strip())
        if section:
            heading = section[1]
            active = heading.startswith("API RESPONSE") or heading == "API WEBSOCKET TIMELINE"
            attempt, response_key, model, pending = heading, "", "", ""
            continue
        if not active:
            continue
        stripped = line.strip()
        if stripped.startswith("data:"):
            stripped = stripped[5:].lstrip()
        if not pending and not stripped.startswith("{"):
            continue
        pending += stripped + "\n"
        try:
            record = json.loads(pending)
        except json.JSONDecodeError:
            continue
        pending = ""
        if not isinstance(record, dict):
            continue
        envelope = record.get("response") or record.get("message") or record
        if not isinstance(envelope, dict):
            continue
        response_key = envelope.get("id") or response_key
        model = envelope.get("model") or model
        for usage in usage_objects(record):
            yield {"ordinal": ordinal, "response_key": response_key or attempt,
                   "model": model, "usage_json": json.dumps(usage, ensure_ascii=True),
                   "tokens": token_leaves(usage)}
            ordinal += 1


def archive(file_path, relative_name, destination):
    """Commit the manifest last. A failed upload can be replayed without duplicates."""
    before = file_path.stat()
    digest = hashlib.sha256()
    with file_path.open("rb") as source:
        for chunk in iter(lambda: source.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    capture_id = hashlib.sha256(relative_name.encode() + b"\0" + digest.digest()).hexdigest()
    chunk_count = 0
    check_digest = hashlib.sha256()
    with file_path.open("rb") as source:
        for ordinal, chunk in enumerate(iter(lambda: source.read(CHUNK_SIZE), b"")):
            check_digest.update(chunk)
            destination.insert("chunks", [{"capture_id": capture_id, "ordinal": ordinal,
                                          "content_b64": base64.b64encode(chunk).decode()}])
            chunk_count += 1
    if digest.digest() != check_digest.digest():
        raise RuntimeError("Request log changed during capture; retrying next run")
    rows = []
    with file_path.open(encoding="utf-8", errors="replace") as source:
        for row in observations(source):
            rows.append({"capture_id": capture_id, **row})
            if len(rows) == 500:
                destination.insert("usage_observations", rows)
                rows = []
    destination.insert("usage_observations", rows)
    after = file_path.stat()
    if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
        raise RuntimeError("Request log changed during capture; retrying next run")
    if not chunk_count:
        return
    destination.insert("files", [{"file_name": relative_name, "capture_id": capture_id,
                                 "version": before.st_mtime_ns,
                                 "observed_at": round(time.time(), 3), "bytes": before.st_size,
                                 "chunk_count": chunk_count}])


def collect(log_dir, state_file, destination):
    state_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with closing(sqlite3.connect(state_file)) as state:
        state.execute("CREATE TABLE IF NOT EXISTS files (name TEXT PRIMARY KEY, size INTEGER, mtime INTEGER)")
        for file_path in sorted(log_dir.glob("*.log")):
            # Application logs are unrelated to request captures. Native in-flight
            # spool files use other names and remain on disk until final assembly.
            with file_path.open("rb") as header:
                if header.readline() != b"=== REQUEST INFO ===\n":
                    continue
            metadata = file_path.stat()
            if time.time() - metadata.st_mtime < 5:
                continue
            current = (metadata.st_size, metadata.st_mtime_ns)
            if state.execute("SELECT size, mtime FROM files WHERE name=?", (file_path.name,)).fetchone() == current:
                continue
            archive(file_path, file_path.name, destination)
            state.execute("INSERT OR REPLACE INTO files VALUES (?, ?, ?)", (file_path.name, *current))
            state.commit()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["init", "collect"])
    parser.add_argument("--logs", type=Path, default=Path("/srv/disks/projects/ai-proxy/logs"))
    parser.add_argument("--state", type=Path, default=Path("/srv/disks/projects/ai-proxy/ingest.sqlite"))
    args = parser.parse_args()
    destination = ClickHouse()
    if args.mode == "init":
        for statement in Path(__file__).with_name("schema.sql").read_text().split(";"):
            if statement.strip():
                destination.query(statement)
    else:
        collect(args.logs, args.state, destination)


if __name__ == "__main__":
    main()
