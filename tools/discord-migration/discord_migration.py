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
CONNECT = 1 << 20


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
        return permissions | VIEW_CHANNEL | READ_MESSAGE_HISTORY | CONNECT
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


def can_read_history(channel, permissions):
    required = VIEW_CHANNEL | READ_MESSAGE_HISTORY
    # Discord's message API also requires CONNECT for voice-channel chat.
    if channel["type"] in {2, 13}:
        required |= CONNECT
    return permissions & required == required


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
            "bot_can_read_history": can_read_history(channel, permissions),
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


def verify_archive(output, selected_channel_id=None, source_client=None):
    output = output.resolve()
    exports = sorted(output.rglob("*.json"))
    records = []
    failures = []
    source_checks = []
    seen_channels = set()
    for export in exports:
        if export.name == "inventory.json" or export.name.startswith("verification"):
            continue
        try:
            document = json.loads(export.read_text())
        except json.JSONDecodeError:
            if selected_channel_id is None:
                failures.append({"export": str(export.relative_to(output)), "error": "invalid or incomplete JSON export"})
            continue
        if not isinstance(document, dict) or "messages" not in document or "channel" not in document:
            continue
        if selected_channel_id is not None and str(document["channel"]["id"]) != selected_channel_id:
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
                    confirmed = False
                    if source_client is not None:
                        source_message = source_client.get(f"/channels/{channel_id}/messages/{message['id']}")
                        source_attachment = next(item for item in source_message["attachments"] if item["id"] == attachment["id"])
                        source_digest = hashlib.sha256()
                        source_size = 0
                        source_request = Request(source_attachment["url"], headers={"User-Agent": "SEC-Hive-Migration/0.1"})
                        with urlopen(source_request, timeout=30) as source_file:
                            for chunk in iter(lambda: source_file.read(1024 * 1024), b""):
                                source_digest.update(chunk)
                                source_size += len(chunk)
                        confirmed = source_size == size and source_digest.hexdigest() == digest.hexdigest()
                        source_checks.append({"channel_id": channel_id, "message_id": message["id"], "attachment_id": attachment["id"], "api_declared_bytes": source_attachment["size"], "cdn_bytes": source_size, "sha256": source_digest.hexdigest(), "identical_to_local": confirmed})
                    if not confirmed:
                        failures.append({"channel_id": channel_id, "attachment_id": attachment["id"], "error": "attachment size mismatch"})
                attachments.append({"message_id": message["id"], "attachment_id": attachment["id"], "file": str(file_path.relative_to(output)), "bytes": size, "sha256": digest.hexdigest()})
        records.append({"channel_id": channel_id, "export": str(export.relative_to(output)), "messages": len(messages), "first_message_id": min(message_ids, key=int) if messages else None, "last_message_id": max(message_ids, key=int) if messages else None, "attachments": attachments})
    if not records:
        failures.append({"error": "no channel exports found"})
    if selected_channel_id is not None and selected_channel_id not in seen_channels:
        failures.append({"channel_id": selected_channel_id, "error": "selected channel has no complete export"})
    inventory_file = output / "inventory.json"
    if inventory_file.exists():
        for channel in json.loads(inventory_file.read_text())["manifest"]:
            if selected_channel_id is not None and channel["discord_id"] != selected_channel_id:
                continue
            if channel["type"] in {0, 2, 5, 13} and channel["bot_can_read_history"] and channel["discord_id"] not in seen_channels:
                failures.append({"channel_id": channel["discord_id"], "error": "accessible message channel has no export"})
    result = {"recorded_at": datetime.now(timezone.utc).isoformat(), "selected_channel_id": selected_channel_id, "channels": records, "source_size_checks": source_checks, "failures": failures, "scope": "Local export and attachment integrity; not proof of complete Discord or Matrix history."}
    report_name = "verification.json" if selected_channel_id is None else f"verification-{selected_channel_id}.json"
    write_json(output / report_name, result)
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
    command.add_argument("--channel", type=int, help="Verify one completed channel while the remaining archive is still running")
    command.add_argument("--check-source", action="store_true", help="Independently fetch size-mismatched attachments from Discord and compare bytes")
    args = parser.parse_args()
    if args.command == "verify":
        source_client = Discord(read_token(args.token_file)) if args.check_source else None
        return verify_archive(args.output, str(args.channel) if args.channel is not None else None, source_client)
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
