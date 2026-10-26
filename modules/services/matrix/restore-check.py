import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from urllib.parse import quote, urlencode
from urllib.request import ProxyHandler, Request, build_opener

import yaml


def thumbnail_cache_omitted(source):
    policy_file = source / "media-backup-policy.json"
    if not policy_file.exists():
        return False
    expected = {
        "version": 1,
        "omitted_generated_media_directories": ["local_thumbnails", "remote_thumbnail", "url_cache_thumbnails"],
        "original_media": "preserved",
        "thumbnail_database_metadata": "preserved",
    }
    if json.loads(policy_file.read_text()) != expected:
        raise RuntimeError("Unsupported media backup policy")
    for name in expected["omitted_generated_media_directories"]:
        directory = source / "synapse/media_store" / name
        if directory.exists() and (not directory.is_dir() or any(directory.iterdir())):
            raise RuntimeError("Checkpoint contains omitted thumbnail cache")
    return True


def verify_checkpoint(source):
    if not (source / "COMPLETE").is_file():
        raise RuntimeError("Checkpoint has no completion marker")
    count = 0
    for line in (source / "SHA256SUMS").read_text().splitlines():
        digest, relative = line.split("  ", 1)
        candidate = (source / relative).resolve()
        if not candidate.is_relative_to(source.resolve()):
            raise RuntimeError("Checksum path escapes checkpoint")
        hasher = hashlib.sha256()
        with candidate.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                hasher.update(block)
        if hasher.hexdigest() != digest:
            raise RuntimeError("Checkpoint checksum mismatch")
        count += 1
    if count == 0:
        raise RuntimeError("Checkpoint checksum manifest is empty")
    return count


def require_isolated_network():
    interfaces = {line.split(":", 1)[0].strip() for line in Path("/proc/net/dev").read_text().splitlines()[2:]}
    if interfaces != {"lo"}:
        raise RuntimeError("Restore requires a private network with loopback only")


def wait_for(check, description, timeout=120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = check()
            if result:
                return result
        except OSError:
            pass
        time.sleep(1)
    raise RuntimeError("Timed out: " + description)


def verify_history(base, source):
    opener = build_opener(ProxyHandler({}))
    token = json.loads((source / "verification/sec-hive-pilot.json").read_text())["access_token"]
    manifest = json.loads((source / "verification/history-manifest.json").read_text())
    room = quote(manifest["room_id"], safe="")

    def get(endpoint, raw=False):
        request = Request(base + endpoint, headers={"Authorization": "Bearer " + token})
        with opener.open(request, timeout=45) as response:
            return response.read() if raw else json.load(response)

    wanted = {part["event_id"] for part in manifest["parts"]}
    events = {}
    ordered = []
    pagination = None
    for _ in range(100):
        query = {"dir": "b", "limit": 500}
        if pagination:
            query["from"] = pagination
        page = get("/_matrix/client/v3/rooms/" + room + "/messages?" + urlencode(query))
        for event in page["chunk"]:
            event_id = event["event_id"]
            if event_id in wanted and event_id not in events:
                events[event_id] = event
                ordered.append(event["origin_server_ts"])
        if wanted <= events.keys() or not page["chunk"] or page.get("end") == pagination:
            break
        pagination = page.get("end")
    if wanted != events.keys() or ordered != sorted(ordered, reverse=True):
        raise RuntimeError("Restored history is incomplete or unordered")
    for part in manifest["parts"]:
        event = events[part["event_id"]]
        if event["origin_server_ts"] != part["timestamp"] or event["sender"] != part["sender"]:
            raise RuntimeError("Restored author/timestamp mismatch")
    for attachment in manifest["attachments"]:
        mxc = events[attachment["event_id"]]["content"]["url"].removeprefix("mxc://")
        data = get("/_matrix/client/v1/media/download/" + mxc, raw=True)
        if len(data) != attachment["bytes"] or hashlib.sha256(data).hexdigest() != attachment["sha256"]:
            raise RuntimeError("Restored media differs from independent archive")
    thumbnail_regenerated = False
    if thumbnail_cache_omitted(source):
        image = next((attachment for attachment in manifest["attachments"]
                      if events[attachment["event_id"]]["content"].get("info", {}).get("mimetype")
                      in {"image/png", "image/jpeg", "image/gif", "image/webp"}), None)
        if image is None:
            raise RuntimeError("Restore has no image for thumbnail regeneration check")
        mxc = events[image["event_id"]]["content"]["url"].removeprefix("mxc://")
        thumbnail = get("/_matrix/client/v1/media/thumbnail/" + mxc + "?width=32&height=32&method=scale", raw=True)
        if not thumbnail:
            raise RuntimeError("Restored thumbnail did not regenerate")
        original = get("/_matrix/client/v1/media/download/" + mxc, raw=True)
        if len(original) != image["bytes"] or hashlib.sha256(original).hexdigest() != image["sha256"]:
            raise RuntimeError("Thumbnail regeneration changed original media")
        thumbnail_regenerated = True
    for reply in manifest["replies"]:
        expected = manifest["primary_events"].get(reply["reference"]["messageId"])
        actual = events[reply["event_id"]]["content"].get("m.relates_to", {}).get("m.in_reply_to", {}).get("event_id")
        if not expected or actual != expected:
            raise RuntimeError("Restored reply relation mismatch")
    return {"message_parts": len(events), "attachments": len(manifest["attachments"]), "replies": len(manifest["replies"]),
            "thumbnail_regenerated_from_original": thumbnail_regenerated}


def main():
    require_isolated_network()
    source = Path.cwd() / "input"
    files_checked = verify_checkpoint(source)
    work = Path.cwd() / "work"
    work.mkdir(mode=0o700)
    socket_dir = work / "socket"
    socket_dir.mkdir(mode=0o700)
    environment = dict(os.environ, PGHOST=str(socket_dir), PGUSER="restore_admin", PGDATA=str(work / "postgres"))
    processes = []
    logs = []

    def run(*command, output=False):
        with (work / "commands.log").open("ab") as log:
            result = subprocess.run(command, env=environment, stdout=subprocess.PIPE if output else log, stderr=log, check=True)
            return result.stdout.decode().strip() if output else None

    def start(name, command, process_environment=None, cwd=None):
        log = (work / (name + ".log")).open("wb")
        logs.append(log)
        process = subprocess.Popen(command, env=process_environment or environment, cwd=cwd, stdout=log, stderr=log)
        processes.append(process)
        return process

    try:
        run("initdb", "--no-locale", "--encoding=UTF8", "-U", "restore_admin")
        run("pg_ctl", "-l", str(work / "postgres.log"), "-o", "-c listen_addresses= -c unix_socket_directories=" + str(socket_dir), "-w", "start")
        plural_enabled = (source / "plural-enabled").is_file() and (source / "plural-enabled").read_text().strip() == "1"
        databases = [("matrix-synapse", "synapse.dump"), ("mautrix-discord", "bridge.dump")]
        if plural_enabled:
            databases.append(("pluralmatrix", "plural.dump"))
        for database, dump in databases:
            run("createdb", "--template=template0", "--locale=C", database)
            run("pg_restore", "--exit-on-error", "--no-owner", "--no-acl", "--jobs=2", "-d", database, str(source / dump))
        counts_sql = '''SELECT json_build_object('portals', (SELECT count(*) FROM portal), 'messages', (SELECT count(*) FROM message), 'threads', (SELECT count(*) FROM thread), 'users', (SELECT count(*) FROM "user"))'''
        counts = json.loads(run("psql", "-XAt", "-d", "mautrix-discord", "-c", counts_sql, output=True))
        if counts != json.loads((source / "bridge-counts.json").read_text()):
            raise RuntimeError("Restored bridge mappings differ from checkpoint")
        if plural_enabled:
            plural_counts_sql = '''SELECT json_build_object('systems', (SELECT count(*) FROM "System"), 'members', (SELECT count(*) FROM "Member"), 'switches', (SELECT count(*) FROM "Switch"), 'journal', (SELECT count(*) FROM "InboundEvent"))'''
            plural_counts = json.loads(run("psql", "-XAt", "-d", "pluralmatrix", "-c", plural_counts_sql, output=True))
            if plural_counts != json.loads((source / "plural-counts.json").read_text()):
                raise RuntimeError("Restored PluralMatrix data differs from checkpoint")
            pending = run("psql", "-XAt", "-d", "mautrix-discord", "-c", "SELECT count(*) FROM sec_hive_plural_pending", output=True)
            if pending != (source / "plural-bridge-pending-count").read_text().strip():
                raise RuntimeError("Restored PluralMatrix bridge backlog differs from checkpoint")
        # Sanitize only the isolated restored database before starting the bridge.
        # The real encrypted backup and production credentials remain unchanged.
        run("psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", "mautrix-discord", "-c", 'UPDATE "user" SET discord_token=NULL')
        shutil.copytree(source / "synapse", work / "synapse")
        for entry in (work / "synapse").rglob("*"):
            entry.chmod(0o700 if entry.is_dir() else 0o600)
        (work / "synapse").chmod(0o700)
        registration = yaml.safe_load((source / "bridge/discord-registration.yaml").read_text())
        registration["url"] = "http://127.0.0.1:19334"
        registration_file = work / "discord-registration.yaml"
        registration_file.write_text(yaml.safe_dump(registration))
        synapse = json.loads((source / "synapse-config.json").read_text())
        for key in ("oidc_providers", "saml2_config", "cas_config", "jwt_config", "password_providers"):
            synapse.pop(key, None)
        synapse.update({
            "database": {"name": "psycopg2", "args": {"database": "matrix-synapse", "user": "restore_admin", "host": str(socket_dir)}},
            "listeners": [{"port": 18008, "bind_addresses": ["::1"], "type": "http", "tls": False, "resources": [{"names": ["client"]}]}],
            "app_service_config_files": [str(registration_file)],
            "media_store_path": str(work / "synapse/media_store"),
            "signing_key_path": str(work / "synapse/homeserver.signing.key"),
            "registration_shared_secret_path": str(source / "runtime/matrix-registration-secret"),
            "turn_shared_secret_path": str(source / "runtime/matrix-turn-secret"),
            "turn_uris": [], "report_stats": False, "trusted_key_servers": [],
            "pid_file": str(work / "synapse.pid"), "log_config": None,
        })
        plural_environment = None
        bridge_environment = None
        if plural_enabled:
            shutil.copytree(source / "plural", work / "plural")
            for entry in (work / "plural").rglob("*"):
                entry.chmod(0o700 if entry.is_dir() else 0o600)
            (work / "plural").chmod(0o700)
            plural_registration = work / "plural-registration.yaml"
            plural_registration.write_bytes((source / "plural-registration/registration.yaml").read_bytes())
            synapse["app_service_config_files"].append(str(plural_registration))
            plural_environment = dict(environment, **json.loads((source / "plural-config.json").read_text()))
            # systemd's captured PATH omits the verifier's application binaries.
            plural_environment["PATH"] = environment["PATH"]
            for line in (source / "plural-registration/environment").read_text().splitlines():
                if line:
                    key, value = line.split("=", 1)
                    if key not in {"AS_TOKEN", "JWT_SECRET", "GATEKEEPER_SECRET"}:
                        raise RuntimeError("Unexpected PluralMatrix environment key")
                    plural_environment[key] = value
            plural_environment.update({
                "DATABASE_URL": "postgresql://restore_admin@localhost/pluralmatrix?host=" + str(socket_dir),
                "SYNAPSE_URL": "http://[::1]:18008", "REGISTRATION_PATH": str(plural_registration),
                "PUBLIC_WEB_URL": "http://127.0.0.1:29335",
            })
            bridge_environment = dict(environment, PLURALMATRIX_ROOMS=plural_environment["PLURAL_ALLOWED_ROOMS"],
                PLURALMATRIX_DECISION_URL="http://127.0.0.1:29337/decision",
                PLURALMATRIX_GATEKEEPER_SECRET=plural_environment["GATEKEEPER_SECRET"])
        synapse_file = work / "synapse.json"
        synapse_file.write_text(json.dumps(synapse))
        bridge = yaml.safe_load((source / "bridge/config.yaml").read_text())
        bridge["homeserver"]["address"] = "http://[::1]:18008"
        bridge["appservice"].update({"address": "http://127.0.0.1:19334", "port": 19334})
        bridge["appservice"]["database"]["uri"] = "postgresql://restore_admin@/mautrix-discord?host=" + str(socket_dir)
        bridge["bridge"]["provisioning"]["shared_secret"] = "disable"
        bridge["bridge"]["public_address"] = ""
        if bridge["appservice"]["as_token"] != registration["as_token"] or bridge["appservice"]["hs_token"] != registration["hs_token"]:
            raise RuntimeError("Restored application service tokens do not match")
        bridge_file = work / "bridge.yaml"
        bridge_file.write_text(yaml.safe_dump(bridge))
        start("synapse", ["synapse_homeserver", "--config-path", str(synapse_file), "--keys-directory", str(work / "synapse")])
        opener = build_opener(ProxyHandler({}))
        def live(url):
            with opener.open(url, timeout=5) as response:
                return response.status == 200
        wait_for(lambda: live("http://[::1]:18008/_matrix/client/versions"), "restored Synapse startup")
        if plural_enabled:
            start("pluralmatrix", ["pluralmatrix"], plural_environment, work / "plural")
            wait_for(lambda: live("http://127.0.0.1:29335/health"), "restored PluralMatrix startup")
        start("bridge", ["mautrix-discord", "--config", str(bridge_file), "--registration", str(registration_file)], bridge_environment)
        wait_for(lambda: live("http://127.0.0.1:19334/_matrix/mau/live"), "restored bridge startup")
        result = verify_history("http://[::1]:18008", source)
        result.update({"checkpoint_files_checked": files_checked, "bridge_counts_match": True, "bridge_started": True, "external_network": False})
        if plural_enabled:
            result.update({"plural_counts_match": True, "plural_started": True, "plural_backlog_count_matches": True})
        (work / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result))
    finally:
        for process in reversed(processes):
            process.terminate()
            try:
                process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if (work / "postgres/postmaster.pid").exists():
            run("pg_ctl", "-m", "fast", "-w", "stop")
        for log in logs:
            log.close()


if __name__ == "__main__":
    main()
