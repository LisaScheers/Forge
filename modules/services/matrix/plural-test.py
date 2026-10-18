import json
from pathlib import Path
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, ProxyHandler, build_opener
import uuid

opener = build_opener(ProxyHandler({}))
matrix = "http://[::1]:8008"
app = "http://127.0.0.1:29335"


def request(base, endpoint, method="GET", data=None, token=None, expected=200):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = Request(base + endpoint, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        response = opener.open(req, timeout=30)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        assert response.status == expected, (endpoint, response.status, expected)
        return json.loads(content) if "application/json" in response.headers.get("Content-Type", "") else content.decode()


def wait_for(check, description, timeout=120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            value = check()
            if value:
                return value
        except (OSError, AssertionError):
            pass
        time.sleep(0.25)
    raise RuntimeError("Timed out: " + description)


def sql(statement):
    return subprocess.run(["runuser", "-u", "postgres", "--", "psql", "-XAt", "-v", "ON_ERROR_STOP=1", "-d", "pluralmatrix"],
                          input=statement, text=True, capture_output=True, check=True).stdout.strip()


def restart():
    subprocess.run(["systemctl", "restart", "pluralmatrix"], check=True)
    wait_for(lambda: request(app, "/health"), "PluralMatrix startup")


users = {}
for name in ("owner", "peer", "outsider"):
    result = request(matrix, "/_matrix/client/v3/register", "POST", {
        "username": name, "password": "isolated-fixture-password", "auth": {"type": "m.login.dummy"}})
    users[name] = result

owner = users["owner"]["access_token"]
peer = users["peer"]["access_token"]
bot = "@plural_bot:plural.test"
room = request(matrix, "/_matrix/client/v3/createRoom", "POST", {
    "preset": "private_chat", "room_version": "11", "invite": [bot, users["peer"]["user_id"]],
    "power_level_content_override": {"users": {users["owner"]["user_id"]: 100, bot: 50},
        "users_default": 0, "events_default": 0, "state_default": 50, "invite": 50, "kick": 50, "ban": 50, "redact": 50}}, owner)["room_id"]
room_path = "/_matrix/client/v3/rooms/" + quote(room, safe="")
request(matrix, room_path + "/join", "POST", {}, peer)
request(matrix, room_path + "/join", "POST", {}, users["outsider"]["access_token"], expected=403)
other = request(matrix, "/_matrix/client/v3/createRoom", "POST", {"preset": "private_chat", "invite": [bot]}, owner)["room_id"]
Path("/run/pluralmatrix-test-environment").write_text("PLURAL_ALLOWED_ROOMS=" + room + "\n")
restart()
wait_for(lambda: request(matrix, room_path + "/state/m.room.member/" + quote(bot, safe=""), token=owner).get("membership") == "join", "bot joined approved room")
assert request(matrix, "/_matrix/client/v3/rooms/" + quote(other, safe="") + "/state/m.room.member/" + quote(bot, safe=""), token=owner)["membership"] == "invite"

tokens = {}
systems = {}
members = {}
for name in ("owner", "peer"):
    tokens[name] = request(app, "/api/auth/login", "POST", {"mxid": users[name]["user_id"], "password": "isolated-fixture-password"})["token"]
    systems[name] = request(app, "/api/system", "POST", {}, tokens[name], expected=201)
    members[name] = request(app, "/api/members", "POST", {"name": "Alpha" if name == "owner" else "Beta",
        "slug": name, "proxyTags": [{"prefix": name + ":", "suffix": ""}]}, tokens[name], expected=201)

request(app, "/api/auth/login", "POST", {"mxid": "@owner:untrusted.invalid", "password": "irrelevant"}, expected=403)
request(app, "/api/system/links", "POST", {"targetMxid": users["peer"]["user_id"]}, tokens["owner"], expected=403)
request(app, "/api/members/" + members["peer"]["id"], "PATCH", {"name": "forbidden"}, tokens["owner"], expected=404)
request(app, "/api/system", "PATCH", {"autoproxyId": members["peer"]["id"]}, tokens["owner"], expected=400)
request(app, "/api/system/switches", "POST", {"members": [members["peer"]["id"]]}, tokens["owner"], expected=400)
request(app, "/api/groups", "POST", {"name": "foreign group", "slug": "foreign", "members": [members["peer"]["id"]]}, tokens["owner"], expected=400)
request("http://127.0.0.1:29336", "/_matrix/app/v1/transactions/forged", "PUT", {"events": []}, "wrong", expected=401)

import_token = request(app, "/api/auth/login", "POST", {"mxid": users["outsider"]["user_id"], "password": "isolated-fixture-password"})["token"]
imported = request(app, "/api/import/pk/json", "POST", {"name": "Import fixture", "members": [
    {"id": "imported", "name": "Imported", "proxy_tags": [{"prefix": "", "suffix": ":import"}],
     "avatar_url": "https://127.0.0.1/private"}]}, import_token)
assert imported["success"] and imported["count"] == 1 and len(imported["failedAvatars"]) == 1
assert request(app, "/api/members", token=import_token)[0]["proxyTags"] == [{"prefix": "", "suffix": ":import"}]
assert len(request(app, "/api/members", token=tokens["owner"])) == 1


def send(body, token=owner, extra=None):
    content = {"msgtype": "m.text", "body": body}
    content.update(extra or {})
    return request(matrix, room_path + "/send/m.room.message/" + uuid.uuid4().hex, "PUT", content, token)["event_id"]


def history():
    return request(matrix, room_path + "/messages?dir=b&limit=100", token=owner)["chunk"]


def proxied(body):
    matches = [event for event in history() if event["sender"].startswith("@_plural_") and event.get("content", {}).get("body") == body]
    return matches[0] if matches else None


original = send("owner:hello from Alpha")
first = wait_for(lambda: proxied("hello from Alpha"), "first member proxy")
wait_for(lambda: request(matrix, room_path + "/event/" + quote(original, safe=""), token=owner).get("unsigned", {}).get("redacted_because"), "original removed after replacement")
assert first["sender"] == "@_plural_" + systems["owner"]["slug"] + "_owner:plural.test"
send("peer:hello from Beta", peer)
wait_for(lambda: proxied("hello from Beta"), "second member proxy")
levels = request(matrix, room_path + "/state/m.room.power_levels/", token=owner)
assert levels["users"].get(users["peer"]["user_id"], levels.get("users_default", 0)) == 0
assert levels["users"].get(first["sender"], levels.get("users_default", 0)) == 0

# Bridge actors and linked-account provenance must not trigger proxy controls.
bridge_actor = request(matrix, "/_matrix/client/v3/register", "POST", {
    "username": "discord_12345", "password": "isolated-fixture-password", "auth": {"type": "m.login.dummy"}})
request(matrix, room_path + "/invite", "POST", {"user_id": bridge_actor["user_id"]}, owner)
request(matrix, room_path + "/join", "POST", {}, bridge_actor["access_token"])
ordinary_target = send("ordinary reaction target")
preserved_reactions = []
for key in ("❓", "❌", "🔔"):
    for reactor, target, extra in (
        (bridge_actor["access_token"], first["event_id"], {}),
        (owner, first["event_id"], {"fi.mau.discord.source_reaction": True}),
        (owner, ordinary_target, {}),
    ):
        preserved_reactions.append(request(matrix, room_path + "/send/m.reaction/" + uuid.uuid4().hex, "PUT", {
            "m.relates_to": {"rel_type": "m.annotation", "event_id": target, "key": key}, **extra}, reactor)["event_id"])
time.sleep(2)
for event_id in preserved_reactions:
    assert request(matrix, room_path + "/event/" + quote(event_id, safe=""), token=owner)["content"].get("m.relates_to")
assert request(matrix, room_path + "/event/" + quote(first["event_id"], safe=""), token=owner)["content"].get("body") == "hello from Alpha"
send("owner:reaction control target")
control_target = wait_for(lambda: proxied("reaction control target"), "reaction control target")
request(matrix, room_path + "/send/m.reaction/" + uuid.uuid4().hex, "PUT", {
    "m.relates_to": {"rel_type": "m.annotation", "event_id": control_target["event_id"], "key": "❌"}}, owner)
wait_for(lambda: request(matrix, room_path + "/event/" + quote(control_target["event_id"], safe=""), token=owner).get("unsigned", {}).get("redacted_because"), "owner reaction deletion still works")

thread_root = send("ordinary thread root")
send("owner:thread child", extra={"m.relates_to": {"rel_type": "m.thread", "event_id": thread_root, "is_falling_back": True}})
child = wait_for(lambda: proxied("thread child"), "thread proxy")
assert child["content"]["m.relates_to"]["event_id"] == thread_root
send("pk;e edited thread child")
wait_for(lambda: any(event.get("content", {}).get("m.relates_to", {}).get("rel_type") == "m.replace" and
    event["content"]["m.relates_to"].get("event_id") == child["event_id"] for event in history()), "proxied edit")

request(app, "/api/system/switches", "POST", {"members": [members["owner"]["id"]]}, tokens["owner"])
request(app, "/api/system", "PATCH", {"autoproxyMode": "front"}, tokens["owner"])
send("front-mode message")
wait_for(lambda: proxied("front-mode message"), "front-based autoproxy")
request(app, "/api/system", "PATCH", {"autoproxyMode": "off"}, tokens["owner"])

# Crash after Matrix accepts the replacement but before the app commits its ACK.
sql('''CREATE FUNCTION hold_delivery() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN IF NEW."deliveredEventId" IS NOT NULL AND OLD."deliveredEventId" IS NULL THEN PERFORM pg_sleep(60); END IF; RETURN NEW; END $$;
CREATE TRIGGER hold_delivery BEFORE UPDATE ON "InboundEvent" FOR EACH ROW EXECUTE FUNCTION hold_delivery();''')
send("owner:survives uncertain acknowledgement")
wait_for(lambda: proxied("survives uncertain acknowledgement"), "replacement accepted before crash")
subprocess.run(["systemctl", "kill", "--kill-whom=all", "--signal=SIGKILL", "pluralmatrix"], check=True)
sql('''SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE usename='pluralmatrix' AND state='active';
DROP TRIGGER hold_delivery ON "InboundEvent"; DROP FUNCTION hold_delivery();''')
restart()
wait_for(lambda: sql('SELECT count(*) FROM "InboundEvent" WHERE NOT done AND delivery IS NOT NULL') == "0", "durable replay completed")
assert sum(event.get("content", {}).get("body") == "survives uncertain acknowledgement" and event["sender"].startswith("@_plural_") for event in history()) == 1

subprocess.run(["systemctl", "stop", "pluralmatrix"], check=True)
request(matrix, room_path + "/kick", "POST", {"user_id": users["peer"]["user_id"]}, owner)
restart()
peer_ghost = "@_plural_" + systems["peer"]["slug"] + "_peer:plural.test"
wait_for(lambda: request(matrix, room_path + "/state/m.room.member/" + quote(peer_ghost, safe=""), token=owner)["membership"] == "leave", "removed member ghost leaves after restart")

print(json.dumps({"proxy": True, "thread_relations": True, "edit": True, "front_autoproxy": True,
    "access_checks": True, "pk_json_import": True, "uncertain_ack_restart_without_duplicate": True, "offline_membership_cleanup": True}))
