import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import time
from urllib.error import HTTPError
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen


BOT_ID = "1561338659536375828"
VIEW_CHANNEL = 1 << 10
READ_MESSAGE_HISTORY = 1 << 16
ADMINISTRATOR = 1 << 3


def read_token(file_path):
    metadata = file_path.stat()
    if metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) & 0o077:
        raise ValueError("The bot token must be owned by the current user and private (0600).")
    token = file_path.read_text().strip().removeprefix("Bot ")
    if not token or any(character.isspace() for character in token):
        raise ValueError("The bot token file is empty or malformed.")
    return token


def private_directory(directory):
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    directory.chmod(0o700)


def write_json(file_path, value):
    temporary = file_path.with_suffix(file_path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(file_path)


class Discord:
    def __init__(self, token):
        self.token = token

    def get(self, endpoint):
        request = Request(
            "https://discord.com/api/v10" + endpoint,
            headers={"Authorization": "Bot " + self.token, "User-Agent": "SEC-Hive-Migration/0.1"},
        )
        for attempt in range(6):
            try:
                with urlopen(request, timeout=30) as response:
                    result = json.load(response)
                    if response.headers.get("X-RateLimit-Remaining") == "0":
                        time.sleep(float(response.headers.get("X-RateLimit-Reset-After", "1")))
                    return result
            except HTTPError as error:
                if error.code == 429 and attempt < 5:
                    time.sleep(float(json.load(error).get("retry_after", 1)) + 0.1)
                elif error.code >= 500 and attempt < 5:
                    time.sleep(2**attempt)
                else:
                    raise RuntimeError(f"Discord returned HTTP {error.code} for {endpoint}.") from None
        raise RuntimeError("Discord request exhausted its retries.")


def permissions_for(channel, guild_id, roles, member):
    member_roles = {guild_id, *member["roles"]}
    permissions = 0
    for role in roles:
        if role["id"] in member_roles:
            permissions |= int(role["permissions"])
    if permissions & ADMINISTRATOR:
        return permissions | VIEW_CHANNEL | READ_MESSAGE_HISTORY
    overwrites = channel.get("permission_overwrites", [])
    for overwrite in overwrites:
        if overwrite["id"] == guild_id and overwrite["type"] == 0:
            permissions = permissions & ~int(overwrite["deny"]) | int(overwrite["allow"])
    role_deny = role_allow = 0
    for overwrite in overwrites:
        if overwrite["id"] in member_roles - {guild_id} and overwrite["type"] == 0:
            role_deny |= int(overwrite["deny"])
            role_allow |= int(overwrite["allow"])
    permissions = permissions & ~role_deny | role_allow
    for overwrite in overwrites:
        if overwrite["id"] == member["user"]["id"] and overwrite["type"] == 1:
            permissions = permissions & ~int(overwrite["deny"]) | int(overwrite["allow"])
    return permissions


def inventory(client, guild_id, output):
    private_directory(output)
    guild = client.get(f"/guilds/{guild_id}?with_counts=true")
    roles = client.get(f"/guilds/{guild_id}/roles")
    member = client.get(f"/guilds/{guild_id}/members/{BOT_ID}")
    channels = client.get(f"/guilds/{guild_id}/channels")
    threads = client.get(f"/guilds/{guild_id}/threads/active")
    manifest = []
    for channel in channels:
        permissions = permissions_for(channel, guild_id, roles, member)
        manifest.append({
            "discord_id": channel["id"],
            "name": channel["name"],
            "type": channel["type"],
            "parent_id": channel.get("parent_id"),
            "last_message_id": channel.get("last_message_id"),
            "bot_can_view": bool(permissions & VIEW_CHANNEL),
            "bot_can_read_history": bool(permissions & VIEW_CHANNEL and permissions & READ_MESSAGE_HISTORY),
            "matrix_room_id": None,
            "migration_state": "not_started",
        })
    result = {
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "guild": guild,
        "roles": roles,
        "bot_member": member,
        "channels": channels,
        "active_threads": threads,
        "manifest": manifest,
        "archived_threads": "Enumerated by archive --include-threads All; verify against export results.",
    }
    write_json(output / "inventory.json", result)
    print(json.dumps({
        "guild_id": guild_id,
        "guild_name": guild["name"],
        "channels": len(channels),
        "active_threads": len(threads["threads"]),
        "channels_hidden_from_bot": sum(not item["bot_can_view"] for item in manifest),
        "channel_types": {str(kind): sum(item["type"] == kind for item in channels) for kind in sorted({item["type"] for item in channels})},
    }, indent=2))


def verify_archive(output):
    output = output.resolve()
    exports = sorted(output.rglob("*.json"))
    records = []
    failures = []
    seen_channels = set()
    for export in exports:
        if export.name in {"inventory.json", "verification.json"}:
            continue
        document = json.loads(export.read_text())
        if not isinstance(document, dict) or "messages" not in document or "channel" not in document:
            continue
        messages = document["messages"]
        channel_id = document["channel"]["id"]
        seen_channels.add(str(channel_id))
        message_ids = [str(message["id"]) for message in messages]
        if len(set(message_ids)) != len(message_ids):
            failures.append({"channel_id": channel_id, "error": "duplicate message IDs"})
        if document.get("messageCount") != len(messages):
            failures.append({"channel_id": channel_id, "error": "export message count mismatch"})
        attachments = []
        for message in messages:
            for attachment in message.get("attachments", []):
                location = urlsplit(attachment["url"])
                if location.scheme or location.netloc:
                    failures.append({"channel_id": channel_id, "message_id": message["id"], "attachment_id": attachment["id"], "error": "attachment is not stored locally"})
                    continue
                file_path = (export.parent / unquote(location.path)).resolve()
                if not file_path.is_relative_to(output) or not file_path.is_file():
                    failures.append({"channel_id": channel_id, "message_id": message["id"], "attachment_id": attachment["id"], "error": "attachment missing or outside archive"})
                    continue
                digest = hashlib.sha256()
                with file_path.open("rb") as attachment_file:
                    for chunk in iter(lambda: attachment_file.read(1024 * 1024), b""):
                        digest.update(chunk)
                size = file_path.stat().st_size
                if "fileSizeBytes" in attachment and size != attachment["fileSizeBytes"]:
                    failures.append({"channel_id": channel_id, "attachment_id": attachment["id"], "error": "attachment size mismatch"})
                attachments.append({"message_id": message["id"], "attachment_id": attachment["id"], "file": str(file_path.relative_to(output)), "bytes": size, "sha256": digest.hexdigest()})
        records.append({"channel_id": channel_id, "export": str(export.relative_to(output)), "messages": len(messages), "first_message_id": min(message_ids, key=int) if messages else None, "last_message_id": max(message_ids, key=int) if messages else None, "attachments": attachments})
    if not records:
        failures.append({"error": "no channel exports found"})
    inventory_file = output / "inventory.json"
    if inventory_file.exists():
        for channel in json.loads(inventory_file.read_text())["manifest"]:
            if channel["type"] in {0, 2, 5, 13} and channel["bot_can_read_history"] and channel["discord_id"] not in seen_channels:
                failures.append({"channel_id": channel["discord_id"], "error": "accessible message channel has no export"})
    result = {"recorded_at": datetime.now(timezone.utc).isoformat(), "channels": records, "failures": failures, "scope": "Local export and attachment integrity; not proof of complete Discord or Matrix history."}
    write_json(output / "verification.json", result)
    print(json.dumps({"exports": len(records), "messages": sum(record["messages"] for record in records), "attachments": sum(len(record["attachments"]) for record in records), "failures": len(failures)}, indent=2))
    return 1 if failures else 0


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description="Inventory and archive SEC-Hive without putting bot credentials in command arguments.")
    parser.add_argument("--token-file", type=Path, default=Path.home() / ".local/share/sec-hive-migration/discord-bot-token")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("guilds")
    for name in ("inventory", "archive"):
        command = commands.add_parser(name)
        command.add_argument("--guild", required=True)
        command.add_argument("--output", type=Path, required=True)
    command = commands.add_parser("verify")
    command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify":
        return verify_archive(args.output)
    token = read_token(args.token_file)
    client = Discord(token)
    identity = client.get("/users/@me")
    if identity.get("id") != BOT_ID or not identity.get("bot"):
        raise ValueError("This credential is not the SEC-Hive bridge bot.")
    guilds = client.get("/users/@me/guilds?limit=200")
    if args.command == "guilds":
        print(json.dumps([{"id": guild["id"], "name": guild["name"]} for guild in guilds], ensure_ascii=False, indent=2))
        return 0
    if args.guild not in {guild["id"] for guild in guilds}:
        raise ValueError("The bot is not a member of the selected guild.")
    if args.command == "inventory":
        inventory(client, args.guild, args.output)
        return 0
    private_directory(args.output)
    environment = dict(os.environ, DISCORD_TOKEN=token)
    return subprocess.run([
        "discordchatexporter-cli", "exportguild", "--guild", args.guild,
        "--include-threads", "All", "--format", "Json", "--markdown", "false",
        "--media", "true", "--reuse-media", "true", "--parallel", "1",
        "--respect-rate-limits", "true", "--utc", "true",
        "--output", str(args.output.resolve()) + "/",
    ], env=environment, check=False).returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
