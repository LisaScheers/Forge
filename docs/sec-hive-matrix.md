# SEC-Hive: Discord ↔ Matrix

Target: Shiny Entity Collection (SEC-Hive). Both platforms remain equal indefinitely.
History: all accessible messages and attachments. An external export does not replace
the required Matrix import.

Discord application: `1561338659536375828` (SEC-Hive Matrix Bridge). Server Members
and Message Content intents enabled. No personal Discord account tokens.
Guild ID: `1293572131086667827`. Lisa confirmed the bot was added on 2026-10-18.
Live pilot selected by Lisa: `#boring-bot-stuff`, channel `1293576317773676584`.
Permanent rooms: federation enabled; encryption disabled (Lisa, 2026-10-18).
This supersedes Lisa's earlier encryption requirement. No rooms existed when the
preference changed. Discord and Matrix servers can read bridged content.

## Encryption decision

The pinned mautrix-discord 0.7.7 depends on `libolm-3.2.16`. Nix refuses to build
that deprecated library because of its known cryptographic issues. Its pinned
mautrix-go 0.16 dependency links directly to libolm; adding a `goolm` build tag
does not provide a replacement in that version. Lisa explicitly declined an
insecure-library exception on 2026-10-18, then explicitly requested disabling
encryption. Build with the supported `nocrypto` tag and remove the libolm build
input. Disable encryption and key sharing in bridge settings; no insecure-package
allowlist is needed.

Alternatives inspected before the preference changed:

- Upstream `megadiscord`, commit `bd79ef827620fa6d2367ec02adde78ddafba664d`:
  modern bridgev2/crypto framework and history code. Upstream explicitly labels it
  not ready for general self-hosting. Its Matrix message conversion still has a
  relay/webhook attachment TODO. A bounded isolated prototype could establish gaps;
  it is not an approved production replacement.
- `matrix-appservice-discord`: no encryption setup in its sample or appservice
  constructor; declared runtime Node 18–20. Not a verified encrypted replacement.
- Palpo's Rust bridge, commit `cb8a4a93056911db09019b2f6aceaa5fff788fe7`:
  explicitly leaves rooms and removes their mappings when encryption is enabled.
  It does not satisfy the encryption requirement.

Sources:
[legacy crypto dependency](https://github.com/mautrix/discord/blob/v0.7.7/go.mod),
[legacy libolm binding](https://github.com/mautrix/go/blob/6bc5698125c2/crypto/olm/olm.go),
[rewrite readiness](https://github.com/mautrix/discord/blob/bd79ef827620fa6d2367ec02adde78ddafba664d/README.md),
[rewrite relay attachment gap](https://github.com/mautrix/discord/blob/bd79ef827620fa6d2367ec02adde78ddafba664d/pkg/msgconv/from-matrix.go),
[Rust bridge's encrypted-room handling](https://github.com/palpo-im/matrix-bridge-discord/blob/cb8a4a93056911db09019b2f6aceaa5fff788fe7/src/bridge.rs#L736).

Completed: live Atlas health/capacity inspection; bot membership verification;
82-channel inventory (65 text, 8 voice, 9 categories), 10 active threads; encrypted
credentials for Lisa and Atlas, with successful Atlas decryption validation.
The bot cannot view 4 text and 2 voice channels; those are explicit coverage gaps.
The exporter discovered 236 threads and started a 309-channel/thread archive.
Atlas now runs the bridge. Only the selected pilot has a message portal; guild
mode is `if-portal-exists`, preventing automatic creation for other channels.
The pilot export contains 1,070 messages and 36 attachments, verified locally.
Three PNGs differ from Discord's declared sizes; fresh downloads from URLs returned
by Discord's message API have identical SHA-256 and byte counts to the local files.
The verification report records these source inconsistencies explicitly. The pilot
initial limit is 2,000; re-measure before creating portals for other channels.

Pilot evidence: all 1,070 source message IDs map to 1,106 Matrix message parts.
An ordinary Matrix member can read every part with the original timestamp and
sender, all 11 reply relations, and all 36 attachments with matching SHA-256.
The same historical messages and files remain readable with the bridge stopped.
Two embedded image URLs returned 404; these are explicit media gaps, separate
from the 36 successfully preserved file attachments.

Live pilot checks passed for ordinary Matrix webhook relay, text and files in both
directions, edits, own-message deletion, replies, existing Discord threads, and an
independent webhook without an echo loop. Matrix replies use linked Discord
embeds. Uninvited Matrix joins and ordinary members changing room access are
denied. Lisa's normal-account acceptance remains required before expansion.

An outage test exposed a missed-message race: queued Matrix sends could become
the newest database message before Discord catch-up, hiding older offline input.
The package patch snapshots incoming root/thread cursors synchronously at READY,
excludes outbound relay messages, and catches up known threads even when gateway
metadata omits the latest message ID. Its database regression test and isolated
NixOS test pass. The deployed fix recovered the previously missed probe and passed
a new simultaneous two-way outage test without duplicate delivery. A separate
test recovered a message in a known thread archived while the bridge was stopped.
This does not establish recovery of offline edits or deletions.

Matrix-only native reactions and new Discord thread creation remain unsupported
by the unpatched upstream relay. Lisa selected attributed reaction notices
(“Alice (Matrix) reacted 👍”) on 2026-10-18. The second package patch implements
notices with the full Matrix account ID in the linked-message embed footer,
disables mentions, and persists notices for removal after restart. It uses existing
message/reaction mappings without a schema change. Thread creation selects a
connected bot session; message attribution continues through the relay webhook.
Webhook thread edits/deletions include the required thread ID. The package tests,
isolated NixOS test, and all three Atlas deployment checks pass. The deployed
pilot verifies two distinct Matrix-only members reacting with the same emoji,
individual notice attribution/full IDs, root and thread notice removal after
restart, bot-owned thread creation, bidirectional replies in the new thread, and
thread edits/deletions. The temporary peer left the room after testing.
An additional reaction handler routes permitted members without a Discord login
around the framework's native-login-only guard. It excludes blocked members,
bridge/ghost senders, personal DMs, and existing native-login handling. Regression
coverage exercises permitted/blocked routing, native-login exclusion, ghost/bot
exclusion, and missing relays, as well as notice formatting and Unicode bounds.

Checks: migration package builds and its 6 permission/attachment tests pass;
enabled Atlas settings evaluate without assertion failures, with all encryption
flags false. The `nocrypto` package builds and its runtime closure contains no
libolm. The NixOS integration test passes with Forge's existing Synapse Authlib
overlay and PostgreSQL 18: bridge startup, Synapse appservice connectivity,
authenticated loopback provisioning, empty initial portal state, and stable
registration tokens after regeneration/restart. Stock Synapse fails its OIDC test
without that existing overlay; no production dependency exception was added.
The repository's dendritic check also fails on the pre-existing
`modules/development/ai-skills/skills/visualize/_package.nix` import; this work does
not change that unrelated baseline.

## Inventory and independent archive

Run from Forge. The helper uses the pinned Nixpkgs DiscordChatExporter and accepts
credentials from a private file, never a command argument. Default token location:
`~/.local/share/sec-hive-migration/discord-bot-token`, mode `0600`.

```sh
nix run .#discord-migration -- guilds
nix run .#discord-migration -- inventory --guild GUILD_ID --output "$HOME/.local/share/sec-hive-migration/archive"
nix run .#discord-migration -- archive --guild GUILD_ID --output "$HOME/.local/share/sec-hive-migration/archive"
nix run .#discord-migration -- verify --output "$HOME/.local/share/sec-hive-migration/archive"
nix run .#discord-migration -- verify --channel CHANNEL_ID --check-source --output "$HOME/.local/share/sec-hive-migration/archive"
```

`inventory.json`: guild/channel/role metadata, effective bot access, active threads,
and initial channel mapping. The exporter enumerates active and archived threads
with `--include-threads All`, downloads assets, and preserves message IDs in JSON.
Inaccessible private threads still require an explicit coverage report.

`verification.json`: export counts, attachment sizes/SHA-256, missing local files,
and missing accessible message-channel exports. This checks local integrity; it
does not establish full source coverage, forum coverage, or successful Matrix import.
`--channel` produces a separate scoped report while other channels are still being
exported. `--check-source` checks size discrepancies against fresh attachment URLs
from Discord's message API and accepts them only when the downloaded bytes match
the local file's size and SHA-256. It never accepts a mismatch by size alone.
Keep exports and credentials outside the repository; do not publish them to PostPlan.

## Bridge foundation

`matrix.discord.enable` defaults to false. Before enabling it, set
`matrix.discord.environmentFile` to an agenix runtime file containing a random
`DISCORD_PROVISIONING_SECRET`, and `matrix.discord.initialBackfillLimit` to a measured
bound covering the largest included channel/thread. Nix assertions reject missing
secrets or a zero history limit. No Discord login or guild link is automatic.

The appservice and provisioning endpoints bind to loopback. Synapse reaches the
bridge locally; the bridge reaches Synapse's IPv6 listener. PostgreSQL has a separate
bridge database and role. Invited members can relay from local or federated Matrix
accounts; invite-only room access controls participation. Administration is limited
to Lisa and the dedicated relay identity.
New bridge rooms are unencrypted. Encrypted Matrix rooms cannot be connected by
this build. Preserve the bridge database and test recovery of room mappings.

Use the local provisioning login endpoint to connect the Discord bot to
`@sec-hive-relay:bylisa.dev`; this avoids placing the bot token in a Matrix message
or command arguments. Preserve the bridge's registration and database together.

## Gates before permanent rooms

- Finish the relevant channel/thread exports and verify the history bound before
  each portal is created; no recent-history fallback. A verified pilot can proceed
  while unrelated channel exports continue.
- Federation enabled and encryption disabled are confirmed. `federateRooms = false`
  is only for disposable local pilot rooms; a permanent room cannot later be made
  federated by changing this flag. Confirm history visibility, membership, and
  moderator powers.
- Prove webhook relay from ordinary members; test edits/deletions, attachments,
  threads/forums, other webhooks, and reconnect/catch-up behavior.
- Import into unused rooms before inviting members. Synapse cannot insert old
  messages into the middle of an existing conversation.
- Preserve channel/guild history if Discord channels are removed or the bot leaves.
- For the pilot, set guild mode to `if-portal-exists` directly, then use
  `create-portal CHANNEL_ID`. Do not use `guilds bridge` or the provisioning guild
  bridge endpoint: they enable creation on messages in other channels. Manual
  `bridge CHANNEL_ID` links an existing room without starting initial backfill.
- Test a coordinated restore of Synapse data/media/signing keys plus bridge state.

Voice/video, permission synchronization, moderation, and Discord-only bots require
separate workflow verification; ordinary text bridging is not evidence of parity.

## Production deployment

Use Forge's normal Atlas deployment gate. It requires a clean checkout whose HEAD
matches `origin/main`, builds the three target checks, and coordinates the updater.
Do not deploy unrelated working-tree changes or bypass the gate.

PostgreSQL backups already include all databases. They do not cover Synapse media,
signing keys, bridge registration/credentials, or off-host recovery by themselves.
A protected pre-bridge backup at `/var/backup/sec-hive-prebridge-20261018` contains
the Synapse database, media/configuration/signing files, checksums, and deployed
generation. Checksums and database dump catalog pass; a coordinated restore and
off-host recovery test remain gates before broader rollout.
