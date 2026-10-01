"""Export only display fields from Kuma, using its SQLite database read-only."""
import concurrent.futures
from contextlib import closing
import datetime
import http.client
import json
import os
from pathlib import Path
import socket
import sqlite3
import ssl
import time
import urllib.parse

ROOT = Path(__file__).parent
STATES = {0: "down", 1: "up", 2: "pending", 3: "maintenance"}


def monitor_check(row, now):
    result = {"name": row["name"], "status": "unknown", "checked": None,
              "latency": row["ping"], "kind": "Monitor check"}
    if not row["active"]:
        result["status"] = "paused"
        return result
    if row["time"]:
        checked = datetime.datetime.fromisoformat(row["time"]).replace(
            tzinfo=datetime.timezone.utc).timestamp()
        result["checked"] = checked
        # Push monitors can legitimately wait a day for backup completion.
        freshness = max(300, row["interval"] + row["retry_interval"] * row["maxretries"] + 120)
        if now - checked <= freshness:
            result["status"] = STATES.get(row["status"], "unknown")
    return result


def http_check(service):
    probe = service["probe"]
    parsed = urllib.parse.urlsplit(probe["url"])
    result = {"name": service["name"], "status": "down", "checked": time.time(),
              "latency": None, "kind": "TCP listener" if probe.get("snapshot") else "HTTP reachability"}
    connection = None
    started = time.monotonic()
    try:
        if parsed.scheme == "https":
            connection = http.client.HTTPSConnection(parsed.hostname, parsed.port or 443, timeout=5)
            if probe.get("address"):
                # Reach Nook over Tailscale while validating the original TLS hostname.
                raw = socket.create_connection((probe["address"], parsed.port or 443), timeout=5)
                try:
                    connection.sock = ssl.create_default_context().wrap_socket(raw, server_hostname=parsed.hostname)
                except Exception:
                    raw.close()
                    raise
        else:
            connection = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=5)
        connection.request("GET", parsed.path or "/", headers={"User-Agent": "LisaDashboard/1"})
        response = connection.getresponse()
        accepted = probe.get("codes", [200, 301, 302, 303, 307, 308])
        result["status"] = "up" if response.status in accepted else "down"
        result["latency"] = round((time.monotonic() - started) * 1000)
        if probe.get("snapshot"):
            result["status"] = "unknown"
            result["latency"] = None
            if response.status == 200:
                local = json.loads(response.read(4096))
                result["checked"] = local["generated"]
                result["status"] = local["status"] if local["status"] in ("up", "down") and 0 <= time.time() - local["generated"] <= 120 else "unknown"
    except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError):
        result["status"] = "unknown" if probe.get("snapshot") else "down"
    finally:
        if connection:
            connection.close()
    return result


def aggregate(checks):
    states = {check["status"] for check in checks}
    for state in ("down", "pending", "unknown", "maintenance", "paused"):
        if state in states:
            return state
    return "up" if checks else "unknown"


def build_snapshot(catalog, monitors, probes, now):
    services = []
    used = set()
    for entry in catalog:
        names = entry.get("monitors", [])
        used.update(names)
        checks = [monitors.get(name, {"name": name, "status": "unknown", "checked": None,
                                     "latency": None, "kind": "Monitor check"}) for name in names]
        if "probe" in entry:
            checks.append(probes[entry["id"]])
        service = {key: entry[key] for key in ("id", "name", "description", "group", "icon", "url", "connection", "local", "network", "public") if key in entry}
        service.update(status=aggregate(checks), checks=checks)
        services.append(service)
    # Every remaining Kuma check appears privately, without monitor URLs or messages.
    for name, check in monitors.items():
        if name not in used:
            services.append({"id": "monitor-" + name, "name": name, "description": check["kind"],
                             "group": "Infrastructure", "icon": "server", "status": check["status"], "checks": [check]})
    return {"generated": now, "services": services}


def collect(database, output):
    catalog = json.loads((ROOT / "catalog.json").read_text())
    now = time.time()
    monitors = {}
    try:
        with closing(sqlite3.connect(f"file:{database}?mode=ro", uri=True, timeout=3)) as db:
            db.row_factory = sqlite3.Row
            # Never select credentials, push tokens, URLs, messages, or saved responses.
            rows = db.execute("""
              SELECT m.name,m.active,m.interval,m.retry_interval,m.maxretries,h.status,h.time,h.ping
              FROM monitor m LEFT JOIN heartbeat h ON h.id =
                (SELECT id FROM heartbeat WHERE monitor_id=m.id ORDER BY id DESC LIMIT 1)
              WHERE m.type != 'group'
            """)
            monitors = {row["name"]: monitor_check(row, now) for row in rows}
    except sqlite3.Error:
        # An unreadable database must not preserve a previous green result.
        print("Kuma status unavailable", flush=True)
        try:
            previous = json.loads((output / "private.json").read_text())
            for service in previous["services"]:
                if service["group"] == "Infrastructure":
                    for check in service["checks"]:
                        monitors[check["name"]] = check | {"status": "unknown"}
        except (OSError, ValueError, KeyError, TypeError):
            pass
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        entries = [entry for entry in catalog if "probe" in entry]
        probes = dict(zip((entry["id"] for entry in entries), pool.map(http_check, entries)))
    snapshot = build_snapshot(catalog, monitors, probes, now)
    output.mkdir(parents=True, exist_ok=True)
    for name, private in (("public", False), ("private", True)):
        view = {"generated": now, "services": [service for service in snapshot["services"]
                  if private or service.get("public", False)]}
        temporary = output / f"{name}.tmp"
        temporary.write_text(json.dumps(view, ensure_ascii=False))
        temporary.chmod(0o640)
        temporary.replace(output / f"{name}.json")


if __name__ == "__main__":
    collect(os.environ.get("KUMA_DATABASE", "/var/lib/uptime-kuma/kuma.db"),
            Path(os.environ.get("DASH_STATUS", "/var/lib/home-dashboard-status")))
