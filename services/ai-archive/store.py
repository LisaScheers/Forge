"""A disposable search index. ClickHouse remains the source of complete captures."""

from contextlib import closing
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sqlite3
import threading
import urllib.parse
import urllib.request

from parser import merge_messages, parse_capture

COUNTERS = ("input_tokens", "output_tokens", "cached_tokens", "reasoning_tokens", "total_tokens")


class ClickHouse:
    def __init__(self, url, password):
        self.url = url.rstrip("/")
        self.password = password

    def query(self, sql, **parameters):
        params = {"query": sql + " FORMAT JSONEachRow", "readonly": "2", "max_execution_time": "45",
                  "wait_end_of_query": "1", **{"param_" + key: value for key, value in parameters.items()}}
        request = urllib.request.Request(self.url + "/?" + urllib.parse.urlencode(params), data=b"", headers={
            "X-ClickHouse-User": "default", "X-ClickHouse-Key": self.password})
        with urllib.request.urlopen(request, timeout=60) as response:
            return [json.loads(line) for line in response if line.strip()]

    def transcript(self, capture_id):
        rows = self.query("SELECT transcript FROM ai_usage.requests WHERE capture_id={capture:String}", capture=capture_id)
        if not rows:
            raise KeyError(capture_id)
        return rows[0]["transcript"]


class Store:
    def __init__(self, path, backend):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.backend = backend
        self.sync_lock = threading.Lock()
        self.last_sync = None
        self.sync_error = False
        self.pending = 0
        with closing(self.connect()) as db, db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS captures (
                    id TEXT PRIMARY KEY, file_name TEXT UNIQUE NOT NULL, observed_at TEXT NOT NULL, bytes INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS turns (
                    id TEXT PRIMARY KEY, capture_id TEXT NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
                    conversation_id TEXT NOT NULL, session_id TEXT NOT NULL, grouping TEXT NOT NULL,
                    started_at TEXT NOT NULL, ordinal INTEGER NOT NULL, model TEXT NOT NULL, client TEXT NOT NULL,
                    provider TEXT NOT NULL, title TEXT NOT NULL, status TEXT NOT NULL,
                    input_tokens INTEGER, output_tokens INTEGER, cached_tokens INTEGER, reasoning_tokens INTEGER,
                    total_tokens INTEGER, detail TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS turns_conversation ON turns(conversation_id,started_at,ordinal);
                CREATE INDEX IF NOT EXISTS turns_time ON turns(started_at);
                CREATE VIRTUAL TABLE IF NOT EXISTS search USING fts5(capture_id UNINDEXED, text);
            """)
            # Rebuild only this disposable projection when its parser format changes.
            if db.execute("PRAGMA user_version").fetchone()[0] != 1:
                db.execute("DELETE FROM search")
                db.execute("DELETE FROM captures")
                db.execute("PRAGMA user_version=1")

    def connect(self):
        db = sqlite3.connect(self.path, timeout=30)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        return db

    def save(self, row, usage):
        turns = parse_capture(row, usage)
        with closing(self.connect()) as db, db:
            previous = db.execute("SELECT id FROM captures WHERE file_name=?", (row["file_name"],)).fetchone()
            if previous:
                db.execute("DELETE FROM search WHERE capture_id=?", (previous[0],))
                db.execute("DELETE FROM captures WHERE id=?", (previous[0],))
            db.execute("INSERT INTO captures VALUES (?,?,?,?)", (row["capture_id"], row["file_name"], row["observed_at"], int(row["bytes"])))
            for turn in turns:
                values = [turn[key] for key in ("id", "capture_id", "conversation_id", "session_id", "grouping", "started_at", "ordinal", "model", "client", "provider", "title", "status", *COUNTERS)]
                db.execute("INSERT INTO turns VALUES (" + ",".join("?" for _ in range(18)) + ")",
                           [*values, json.dumps(turn, ensure_ascii=False)])
            text = "\n".join(message["text"] for turn in turns for message in turn["input"] + turn["output"])
            db.execute("INSERT INTO search VALUES (?,?)", (row["capture_id"], text))

    def sync(self):
        if not self.sync_lock.acquire(blocking=False):
            return
        try:
            files = self.backend.query("SELECT capture_id,file_name,observed_at,bytes FROM ai_usage.files FINAL ORDER BY observed_at DESC")
            with closing(self.connect()) as db:
                known = {row[0] for row in db.execute("SELECT id FROM captures")}
            pending = [row for row in files if row["capture_id"] not in known]
            self.pending = len(pending)
            for metadata in pending[:100]:
                capture = metadata["capture_id"]
                if not re.fullmatch(r"[a-f0-9]{64}", capture):
                    raise ValueError("Invalid capture identity")
                records = self.backend.query("SELECT file_name,capture_id,observed_at,bytes,transcript FROM ai_usage.requests WHERE capture_id={capture:String}", capture=capture)
                if not records:
                    continue
                counters = self.backend.query("SELECT response_key,token_category,token_count FROM ai_usage.token_counts WHERE file_name={file:String}", file=metadata["file_name"])
                usage = {}
                for counter in counters:
                    usage.setdefault(counter["response_key"], {})[counter["token_category"]] = int(counter["token_count"])
                self.save(records[0], usage)
                self.pending -= 1
            self.last_sync = datetime.now(timezone.utc).isoformat()
            self.sync_error = False
        except Exception:
            self.sync_error = True
            raise
        finally:
            self.sync_lock.release()

    def condition(self, filters):
        terms, values = ["1"], []
        if filters.get("days"):
            terms.append("started_at>=?")
            values.append((datetime.now(timezone.utc) - timedelta(days=filters["days"])).isoformat())
        for key in ("model", "client", "provider", "status"):
            if filters.get(key):
                terms.append(f"{key}=?")
                values.append(filters[key])
        if filters.get("q"):
            words = re.findall(r"\w+", filters["q"], flags=re.UNICODE)[:12]
            if words:
                terms.append("capture_id IN (SELECT capture_id FROM search WHERE search MATCH ?)")
                values.append(" AND ".join('"' + word.replace('"', '""') + '"*' for word in words))
        return " AND ".join(terms), values

    def status(self):
        with closing(self.connect()) as db:
            result = dict(db.execute("SELECT count(*) AS captures,coalesce(sum(bytes),0) AS bytes,max(observed_at) AS latest_capture FROM captures").fetchone())
            result["models"] = [row[0] for row in db.execute("SELECT DISTINCT model FROM turns ORDER BY model")]
            result["clients"] = [row[0] for row in db.execute("SELECT DISTINCT client FROM turns ORDER BY client")]
            result["providers"] = [row[0] for row in db.execute("SELECT DISTINCT provider FROM turns ORDER BY provider")]
        return {**result, "last_sync": self.last_sync, "sync_error": self.sync_error, "pending": self.pending}

    def conversations(self, filters, offset=0):
        condition, values = self.condition(filters)
        with closing(self.connect()) as db:
            total = db.execute(f"SELECT count(DISTINCT conversation_id) FROM turns WHERE {condition}", values).fetchone()[0]
            rows = db.execute(f"""SELECT conversation_id AS id,min(started_at) AS started_at,max(started_at) AS updated_at,
                count(*) AS requests,group_concat(DISTINCT model) AS models,group_concat(DISTINCT client) AS clients,
                min(grouping) AS grouping,sum(total_tokens) AS total_tokens,sum(status='error') AS errors
                FROM turns WHERE {condition} GROUP BY conversation_id ORDER BY updated_at DESC,id LIMIT 40 OFFSET ?""", [*values, offset]).fetchall()
            items = []
            for row in rows:
                item = dict(row)
                title = db.execute("SELECT title FROM turns WHERE conversation_id=? AND title NOT IN ('Captured request','Upstream response / attempt') ORDER BY started_at,ordinal LIMIT 1", (item["id"],)).fetchone()
                item["title"] = title[0] if title else "Captured request"
                items.append(item)
        return {"items": items, "total": total, "offset": offset, "has_more": offset + len(items) < total}

    def conversation(self, identity, before=None):
        with closing(self.connect()) as db:
            rows = db.execute("SELECT detail FROM turns WHERE conversation_id=? ORDER BY started_at,ordinal,id", (identity,)).fetchall()
        if not rows:
            raise KeyError(identity)
        turns = [json.loads(row[0]) for row in rows]
        merged = []
        for turn in turns:
            for group in (turn["input"], turn["output"]):
                annotated = [{**message, "request_id": turn["id"], "model": turn["model"], "at": turn["started_at"]} for message in group]
                # Origin annotations do not define message identity across context replays.
                stripped = [{key: value for key, value in message.items() if key not in {"request_id", "model", "at"}} for message in merged]
                normalized = [{key: value for key, value in message.items() if key not in {"request_id", "model", "at"}} for message in annotated]
                joined = merge_messages(stripped, normalized)
                merged.extend(annotated[len(normalized) - (len(joined) - len(stripped)):] if len(joined) > len(stripped) else [])
        end = min(before if before is not None else len(merged), len(merged))
        start = max(0, end - 80)
        summary = [{key: turn.get(key) for key in ("id", "capture_id", "file_name", "model", "client", "provider", "status", "started_at", "response_id", *COUNTERS)} for turn in turns]
        return {"id": identity, "title": next((turn["title"] for turn in turns if turn["title"] not in {"Captured request", "Upstream response / attempt"}), "Captured request"),
                "grouping": turns[0]["grouping"], "session_id": turns[0]["session_id"], "requests": summary,
                "messages": [{**message, "index": index} for index, message in enumerate(merged[start:end], start)],
                "total_messages": len(merged), "before": start if start else None}

    def request(self, identity):
        with closing(self.connect()) as db:
            row = db.execute("SELECT detail FROM turns WHERE id=?", (identity,)).fetchone()
        if not row:
            raise KeyError(identity)
        return json.loads(row[0])

    def analytics(self, filters):
        condition, values = self.condition(filters)
        fields = ",".join(f"sum({key}) AS {key}" for key in COUNTERS)
        with closing(self.connect()) as db:
            totals = dict(db.execute(f"SELECT count(*) AS requests,count(DISTINCT conversation_id) AS conversations,sum(status='error') AS errors,sum(total_tokens IS NULL) AS missing_usage,{fields} FROM turns WHERE {condition}", values).fetchone())
            timeline = [dict(row) for row in db.execute(f"SELECT substr(started_at,1,10) AS day,count(*) AS requests,{fields} FROM turns WHERE {condition} GROUP BY day ORDER BY day", values)]
            models = [dict(row) for row in db.execute(f"SELECT model,provider,count(*) AS requests,{fields} FROM turns WHERE {condition} GROUP BY model,provider ORDER BY total_tokens DESC", values)]
            clients = [dict(row) for row in db.execute(f"SELECT client,count(*) AS requests,sum(total_tokens) AS total_tokens FROM turns WHERE {condition} GROUP BY client ORDER BY total_tokens DESC", values)]
            rows = db.execute(f"SELECT detail FROM turns WHERE {condition}", values).fetchall()
        categories = {}
        for row in rows:
            for key, value in json.loads(row[0])["tokens"].items():
                categories[key] = categories.get(key, 0) + value
        return {"totals": totals, "timeline": timeline, "models": models, "clients": clients,
                "categories": [{"name": key, "tokens": value} for key, value in sorted(categories.items()) if not key.startswith("attribution.")]}
