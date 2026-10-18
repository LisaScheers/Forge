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
denied. On 2026-10-18, Lisa requested testing through her local Element app.
Checks in her existing Element and Discord sessions passed: an Element message
appeared in Discord, a thumbs-up produced the attributed notice with her Matrix
ID, Element created a Discord thread, and a normal Discord reply returned to that
same Element thread. Removing the reaction in Element removed only its Discord
notice. This used the native apps, without extracting personal account tokens.
Wider room access remains a rollout gate. The coordinated off-host restore passed
on 2026-10-18; details follow below.

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

## Membership and moderation

Lisa selected moderator invitations after checking Discord roles on 2026-10-18.
There is no automatic account-linking or role-to-Matrix admission service.

Before inviting anyone, moderators must verify the Matrix account's owner and
their eligibility for that specific Discord channel. Matching display names are
not identity proof. Use Discord channel roles/overwrites as the access reference;
Matrix-only participants need an explicit equivalent access decision from a
moderator. Record approved account IDs in the private channel manifest.

Before each room opens, set invite/kick/ban/redact/state power to 50, normal member
power to 0, and grant administration to Lisa and required bridge identities.
Verify invite-only joining and history visibility before adding members. Ordinary
members must not be able to widen access; the pilot's negative checks establish
the expected policy. Native upstream room defaults are not evidence of this
policy: apply and verify it on every portal before invitations.

Discord role loss, member removal, and bans require the corresponding Matrix
review/removal. Moderator deletion of somebody else's Discord message is not
established by the own-message deletion tests; do not grant Manage Messages or
claim automatic cross-platform moderation without a separate decision and test.

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
generation. Checksums and database dump catalog pass. The coordinated off-host
recovery test below also passes; wider history/access gates remain open.

## Coordinated off-host backup and restore

Lisa approved Nook's HDD destination on 2026-10-18:
`/srv/disks/western-digital-hdd/backups/atlas-matrix`. Restic encrypts the repository;
its password and restricted SSH key are agenix secrets for Lisa and Atlas only.
Nook gets an SFTP-only, chrooted account restricted to Atlas's tailnet address.
Repository setup requires the HDD mount, avoiding a fallback to Nook's root disk.

`restic-backups-matrix.service` stages `/var/backup/matrix-coordinated`: both
Synapse, bridge and PluralMatrix database dumps, Synapse media/signing key,
bridge and PluralMatrix configuration/registration/state,
required Matrix runtime secrets, and private pilot verification inputs. It copies
media before the pause, stops PluralMatrix, bridge and Synapse, captures databases/files at a
common quiescent point, resumes services, and only then hashes/uploads. EXIT and
systemd post-stop cleanup restore the previous running states after failure.
The updater shares the checkpoint lock and skips a pending recovery marker;
manual Atlas deployment refuses an in-progress checkpoint. Do not run concurrent
manual maintenance while taking a checkpoint.

The daily timer is at 02:00 server time (UTC on Atlas), with missed runs caught up
after boot. No snapshots are automatically pruned; retention/deletion policy
remains a separate decision.

The first off-host snapshot, `d8284df2`, completed on 2026-10-18 at 13:13 UTC.
It captured 2.045 GiB and stored 1.767 GiB; Restic's repository check passed.
Synapse and the bridge were stopped from 13:11:12 to 13:11:25 UTC (13 seconds).
Both resumed before upload and remained active afterward.

For a restore rehearsal, restore a specific off-host snapshot into a new protected
`/var/lib/matrix-restore-input` directory with `sudo restic-matrix restore ID
--target /var/lib/matrix-restore-input --verify`, then start
`matrix-restore-check.service`. It rejects incomplete/corrupt checkpoints and any
network namespace containing an interface other than loopback. The dedicated
DynamicUser service cannot access the live PostgreSQL socket or application data.
It restores fresh databases and files, compares bridge mapping counts, starts
separate Synapse, bridge and PluralMatrix processes, and verifies original pilot authors/timestamps,
ordering, replies and every file hash through the restored Matrix client API.
Discord login tokens are cleared only in the isolated restored database before
starting its bridge; the encrypted backup and production credentials are intact.
Logs and detailed results stay in the protected restore StateDirectory.

For real recovery, keep Discord and federation disconnected until validation is
complete. Select one snapshot and its recorded Forge generation; obtain the
repository password from Lisa's recovery copy or agenix with her identity. Nook
cannot decrypt the repository. Restore to a protected staging directory and run
the isolated rehearsal first. Rebuild the matching Nix configuration/roles, stop
all three live applications, and restore all three databases plus Synapse media/signing key,
bridge/PluralMatrix state, registrations and runtime credentials from that same snapshot. Restore
service ownership and confirm the appservice token pair matches registration.
Replacing live databases/files is destructive and needs Lisa's explicit approval;
the rehearsal never performs that step. Start privately, verify client history,
media and mappings, then deliberately reconnect and test both delivery directions.
Messages sent after the selected checkpoint require a separate gap/duplicate
review; restoring an older mapping database alone is not safe recovery.

Five fixture tests cover valid, damaged, incomplete and escaping checkpoints plus
the network guard. A shell test verifies recovery state handling and refuses
invalid state. The first real off-host restore passed on 2026-10-18 at 13:22 UTC:
Restic downloaded and verified all 23,913 files from snapshot `d8284df2`; the
isolated service checked 23,911 content hashes (excluding the checksum manifest
and completion marker), restored both databases, matched bridge mapping counts,
started Synapse and the bridge, and verified 1,106 original pilot message parts,
36 attachment hashes and 11 reply relations through the restored client API.
It completed in 61 seconds after download, with external networking unavailable.
The first attempt exposed an id-mapped mount ownership mismatch; the copy step
now omits production UIDs inside the test directory. The original snapshot still
preserves production ownership. Live services remained active during rehearsal.

## PluralMatrix pilot

Lisa requested implementation on 2026-10-18 after the Matrix alternative review.
The deployment is limited to `#boring-bot-stuff`; it does not enable proxying in
other rooms or create additional portals. Source is pinned to PluralMatrix
`d10e51a4c9fe12cdab226b8241f85716fe37f50f`, packaged declaratively with its
Node/Rust dependencies. Synapse's core remains unmodified. The rooms remain
unencrypted; the packaged Rust crypto dependencies require no libolm exception.

The dashboard is `https://plural.bylisa.dev`; the appservice identity is
`@plural_bot:bylisa.dev`. Local Matrix accounts authenticate against the configured
Synapse endpoint. Passwords are not stored; the temporary Matrix login is logged
out after verification. Remote homeservers need an explicit trusted HTTPS endpoint
in `matrix.plural.loginHomeservers` for dashboard login. Never forward passwords
to user-supplied discovery URLs. The browser receives a seven-day app JWT.

Accounts own their systems/members/groups/switches. Unverified cross-account
linking is disabled. PluralKit JSON import creates a separate Matrix copy;
it is not continuous synchronization with PluralKit on Discord. Existing Discord
PluralKit messages continue through the Discord bridge. Matrix profile messages
appear as attributed webhook messages on Discord, without separate Discord user
accounts or native per-member reactions. Moderator admission remains unchanged.
Only the bot may invite its ghosts; ordinary users retain power level zero.
Ghosts leave when their owning account leaves/is removed, with startup and
periodic reconciliation for missed membership callbacks.

The appservice commits incoming messages to PostgreSQL before acknowledging the
Synapse transaction. It saves the selected identity/content before sending,
uses a stable Matrix transaction ID, and redacts the original only after Matrix
acknowledges the replacement. Matrix clients may briefly show the original; no
Synapse patch hides it before acknowledged delivery. Pending work survives restart. The Discord bridge
keeps a separate PostgreSQL queue and waits for the actual appservice decision;
it forwards ordinary text once, suppresses originals of proxied messages, and
retries missing replacements. A room's backed-off head cannot be overtaken;
other rooms can continue. Failed work remains queued for operator inspection.
This does not establish recovery from the ambiguous Discord accepted-but-response-
lost case, nor does it change the existing offline edit/deletion limitations.

All three HTTP listeners bind loopback. Nginx exposes only the dashboard/API over
HTTPS, limits login requests and request bodies, suppresses API access logs for
JWT-bearing media/export URLs, and sends `Referrer-Policy: no-referrer`. Imports
fetch only bounded HTTPS images from pinned public IPv4 addresses. Credentials
are agenix-encrypted for Lisa and Atlas; Nook gets no decryption identity.

The coordinated backup also stops PluralMatrix before the bridge and Synapse,
waits for application DB connections to drain, then captures its database,
profile/crypto state, appservice registration, runtime credentials and both durable
queues at the same checkpoint. Resume order is Synapse, PluralMatrix, bridge.
The isolated restore compares profile/switch/journal and bridge backlog counts,
starts all three services without external networking, and checks the original
pilot history/media. Restore all three applications from the same checkpoint;
never mix a new profile database with an older Synapse or bridge database.

Validation on 2026-10-18: all 52 selected tests in seven suites pass. Both the
Synapse/PostgreSQL PluralMatrix VM and existing Discord foundation VM pass, as do
the backup boundary checks and all three Atlas deployment gates. The VM verifies
account isolation, PluralKit JSON import, suffix-only proxy tags, private-network
avatar rejection, thread/edit/front behavior, lost-ACK crash replay without a
duplicate, and cleanup after offline member removal. Live pilot checks verify
two names/avatars on Discord, original suppression, threads, edit/delete and front
switching. Ordinary/proxied messages survive a PluralMatrix outage plus bridge
restart exactly once; both queues drain to zero. The public HTTPS dashboard loads
and unauthenticated API access returns 401. Wider rollout remains gated on the
existing history, access and parity checks.

For moderation, webhook display names are not proof of ownership. Resolve the
Matrix sender and its system/account mapping; keep the existing moderator checks
for admission. Discord PluralKit does not manage these Matrix-owned profiles.
For rollback, pause relaying, remove PluralMatrix's bot and ghosts from the pilot
with moderator authority, then revert the Nix enablement and restart Synapse and
the bridge. Preserve the profile database and both queues for gap/duplicate review;
do not delete or blindly replay them against a different checkpoint.
