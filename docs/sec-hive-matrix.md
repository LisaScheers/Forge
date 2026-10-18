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
Atlas now runs the bridge for the pilot and individually reviewed completed
channels. Guild mode is `if-portal-exists`, preventing automatic portal creation.
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

### Completed-export audit, 2026-10-18

Twenty complete exports contain 2,152 messages and 84 attachments. Local ID/count
and attachment integrity checks pass; three declared-size discrepancies are
independently confirmed against identical fresh Discord bytes. The global report
still fails, correctly: one JSON export is being written and 50 accessible root
message channels have no completed export. This is not whole-server verification.

A fresh Discord pagination audit checks all 20 completed root exports. Ten text
channels match the current message-ID set exactly. The pilot has 29 newer messages,
with no missing older IDs, removed source IDs or post-export edits detected. These
are source comparisons, not additional Matrix import proofs. Nine empty exports
cannot be accepted as source coverage: eight voice chats and one inaccessible text
channel return HTTP 403. Four text channels remain hidden from the bot overall.
Discord requires CONNECT as well as VIEW_CHANNEL and READ_MESSAGE_HISTORY to read
voice-channel chat; the inventory helper now includes that requirement. All eight
voice chats currently fail the source check, including six the bot can view.

The private `rollout-review/readiness.json` under the migration state directory
records current role overwrites, per-channel history bounds, source gaps, approved
account IDs and Space mappings. Approval lists start empty except the verified
pilot. Do not turn individual-role visibility or bot access into automatic Matrix
admission. Root-channel ID comparisons do not verify archived/private threads,
message content, embedded assets or Matrix import.

Source: [Discord message endpoint permissions](https://github.com/discord/discord-api-docs/blob/main/developers/resources/message.mdx#get-channel-messages).

### Space navigation

The invite-only SEC-Hive root Space and its Admin stuff subspace now exist; the
pilot and verified incremental rooms are linked under Admin stuff. Lisa has invitations to both Spaces. Creation,
federation, no encryption, moderator-only state/invitations, reciprocal parent/child
links and the hierarchy API are verified. An uninvited ordinary fixture cannot
read either Space's state. Each additional message portal requires its own source audit.

Navigation is explicitly maintained separately from native guild bridging, so the
guild stays in `if-portal-exists` mode. Do not run `guilds bridge` to create a second
root: it would enable automatic channel creation. The protected `spaces.json` and
`space-ops.py` in Atlas's migration state directory record/manage the existing root,
category and pilot links. Add reviewed categories and rooms to this same hierarchy
as they migrate. Space membership never grants channel membership; review which
category names and child links an audience may see before inviting it. Room/Space
state is persisted by Synapse; these newly created links are newer than the last
restore-tested checkpoint and will enter the next coordinated backup.

### Completed-channel rollout, 2026-10-18

Ten additional channels are now live under Admin stuff: `join`, `suggestions`,
`rules-and-philosophy`, `introductions`, `stream-notifications`,
`lore-glossary-definitions`, `blocked-messages`, `vetting`, `ask-to-dm`, and
`announcements`. All 64 audited public threads are imported into their parent
rooms. The root Space, category and 11 message rooms produce 13 verified hierarchy
entries. Lisa is invited; ordinary admissions remain subject to moderator review.

The additional batch verifies 2,301 original source IDs as 2,360 Matrix parts,
78 attachment SHA-256 hashes and 293 reply relations, with no missing reply
references. Every part's author, timestamp, thread relation and readable timeline
order is checked through the Matrix client API. These counts exclude the original
pilot's 1,070 messages, 1,106 parts, 36 files and 11 replies. The public-thread
audit retains 27 structural starter wrappers and two thread-renaming events.
The moderation converter preserves all 229 moderation notices in blocked-messages.

Lisa subsequently removed the read-only policy for join and rules-and-philosophy
on 2026-10-18. Both have Discord Manage Webhooks permission and use the same
relay and PluralMatrix policy as the other rooms. All 11 rooms permit posting;
the pilot remains the end-to-end live behavior proof. Both application
queues were empty and all three services healthy after import; guild mode stays
`if-portal-exists`.

Two failed staging copies are preserved, renamed and tombstoned toward their
verified replacements. One linked-account historical event had lost its original
timestamp; another partial import skipped moderation embeds. Replacing these
staging portals preserved chronology without deleting either old room. Operational
requests honor Matrix's retry delay while retaining the original transaction ID.
Discord-provided embedded image/icon/preview URLs also produced HTTP 404s; these
are recorded separately from the 78 successfully verified file attachments.
The full-server archive and unjoined private-thread coverage remain unfinished.

Post-rollout encrypted off-host snapshot `befbbb95` was saved at 16:17 UTC;
the backup and repository check completed at 16:18 UTC with no errors. It captures
26,961 files and 2.124 GiB, adding 260.216 MiB of new data (200.972 MiB stored).
All three live applications resumed before off-host upload. This batch has not
undergone a fresh isolated restore; the earlier restore proof covers the pilot.

## Bridge foundation

### General-category rollout, 2026-10-18

Four more rooms are live under the private General subspace: special-interests,
quotes, fashion-outfits and stories. Both accessible public special-interests
threads are imported. This batch verifies 3,298 source IDs, 3,471 Matrix parts,
230 attachment hashes and 527 reply relations, with no missing reply references.
All 15 message rooms have configured relays and PluralMatrix membership; the
18-entry hierarchy includes the root, Admin stuff and General Spaces. Both queues
were empty after verification. Ordinary admissions still require moderator review.

Encrypted off-host snapshot `521755c2` captures 30,242 files and 2.479 GiB.
The backup/repository check passed at 19:22 Brussels time on 2026-10-18. This
checkpoint has not undergone a fresh isolated restore; the earlier restore proof
remains the pilot proof. General's separate completed export contains 78,922
messages and 1,077 file attachments. A later source scan covers 78,978 messages:
56 newer arrivals, no missing older IDs or deletions, no changed attachment sets
or authors. Its 18 text differences are pins, joins, thread creation and poll
results rendered differently by the exporter. The prepared raw snapshot retains
1,090 file hashes, including ten forwarded files and three newer attachments;
1.216 GB of file bytes. One newer PNG has inconsistent size metadata, but a
second fresh source download matches its local bytes and SHA-256. General's three
accessible public threads independently verify 224 raw messages and seven files.
Unjoined private-thread coverage remains unavailable. A subsequent complete source audit covers 79,029 root messages with no missing
older IDs, deletions, changed attachment sets or changed authors. The current
snapshot preserves 1,092 root file hashes (1,218,723,098 bytes), and its three
public threads still verify 224 raw messages and seven files. Unchanged archived
files were rehashed; new size discrepancies were checked against a second source
download. Atlas had 37.7 GB free before import, against 2.65 GB of referenced local
export assets. The deployed initial bound is 90,000 messages. General is bound to
a private, unlisted staging room and its native import is running. Do not restart
the bridge during initial collection/import; original IDs, authors, timestamps,
chronology, replies and every file hash must pass before admission. Finalization
also classifies missing reply targets against Discord; accessible unresolved
targets block admission. A new coordinated backup waits until active initial
imports finish.

### Prepared batch and content gaps, 2026-10-18

Another 14 channels and 79 public threads have completed independent export and
fresh source-ID verification: 10,357 raw messages and 265 ordinary file hashes.
Ten additional files inside forwarded snapshots were downloaded and hashed
separately, bringing the prepared batch to 275 file hashes. A later refreshed
export verifies 10,359 raw messages before rollout. The five additional private
category Spaces preserve Discord placement. Import controllers verify each room
and all of its public threads before linking the room and inviting Lisa.

`discord-history-content.patch` preserves poll questions, answer choices and count
snapshots, poll-result embeds, forwarded attachments/stickers/embeds, and nested
bot-message text, button labels and media links. Poll voting and component actions
remain on Discord. Forwarded media uses the forwarding message's author, ID and
room; slice copies leave cached source payloads unchanged. Edits retain forwarded
attachment IDs so native edit handling does not remove those files accidentally.
Package tests and the isolated Synapse/PostgreSQL integration check pass.

The converter and reaction-control repair are confirmed deployed through normal
Atlas deployment gates (commits e1dbea9 and 4f6a430). Lisa restored SSH/Git signing;
no bypass was used. The actual running bridge executable and configuration were
checked, including the 90,000-message initial bound. Synapse, mautrix-discord,
PluralMatrix and the auto-update timer are active.

The expanded audit also found seven forwarded files in previously opened rooms
(two Admin stuff thread files and five special-interests files). Their bytes and
hashes were preserved locally, then repaired and verified through an ordinary
Matrix account. All 265 older component messages were also reconciled. The live
repair proof and its mapping/timestamp limits are recorded below. Earlier
ordinary-attachment counts exclude these seven supplementary files.

### Historical reactions

The previous message imports did not import historical reaction rosters. The
first ten additional channels contain 384 source reaction groups, while their
bridge reaction table initially had no corresponding mappings. Message/file
preservation counts do not establish historical reaction coverage.

`import-reactions MESSAGE_ID [MESSAGE_ID...]` is restricted to bridge admins and
at most 20 already bridged guild messages. Private threads cannot be imported
through a parent portal. It fetches current reaction users with full pagination,
including normal and burst kinds, and sends imports through the portal's event
loop. Existing mappings make retries idempotent. Historical reactions use ghost
identities even when their owners have linked real Matrix accounts.

Matrix displays one reaction per person and emoji; normal/burst distinctions are
retained in `fi.mau.discord.imported_reaction.types`. Original reaction times are
unavailable, so imported events use import time and explicitly mark that limitation.
Historical removals check whether the person still has another kind of that
reaction, use the original event author's identity, and retain mappings if a
redaction fails. Custom emoji lookup tolerates name changes by using its stable ID.
This adds current-roster import, not a guarantee of offline reaction reconciliation.

A live import exposed PluralMatrix treating Discord's question-mark reactions as
its own commands and redacting them. The reaction-control patch ignores Discord
ghosts, bridge provenance (including linked accounts) and historical-import tags;
ordinary controls apply only to local PluralMatrix-owned messages. The bridge now
marks every Discord reaction's provenance and can replace a server-confirmed
redacted historical mapping when the source roster still contains that person.
The isolated test preserves question/cross/bell reactions from a Discord actor,
from a marked linked account and on an ordinary message, while owner cross-reaction
deletion of a proxied message still works. Package and integration checks pass.

All seven previously missing forwarded files are restored as Matrix thread
supplements linked from their original messages. Ordinary-account downloads match
their source hashes; original event IDs and timestamps remain unchanged. These
supplements use restoration times and do not add native bridge message-part
mappings: react to the original message for its Discord counterpart. All 265
older component messages have verified edits retaining their visible labels/text.
Source payloads, restoration transaction IDs and proofs remain in the protected
migration state. New imports use the corrected native converter directly.

The 21:32 UTC checkpoint has 29 live rooms. All fourteen rooms from the latest
batch add 10,359 preserved source events, 10,568 native Matrix parts, 275 file
hashes, 2,023 verified replies and 79 public threads. Three missing reply targets all
return Discord HTTP 404. One empty thread-recipient removal event, skipped by the
legacy converter, is retained as an explicitly dated import-time thread notice;
its author, source payload digest, thread relation and ordinary-account visibility
are verified. It has no native message mapping. The remaining source events keep
their original timestamps and verified order. Stable transaction/journal reuse
preserves the same supplementary event on retry.

The 22:46 UTC audit confirms 31 live rooms under the root plus seven category
Spaces, with reciprocal links, webhook relays, PluralMatrix and moderator-only
invitations/state. General verifies 79,029 original root messages, 79,753 native
parts, 1,092 file hashes and 15,177 replies, plus three public threads containing
224 source events and seven files. Beep-stim-chat verifies 7,304 root messages,
7,322 parts, 38 file hashes and 1,106 replies. Fourteen General and two beep
missing reply targets were checked against Discord: all are unavailable at the
source. Both rooms are listed and Lisa is invited. The normal Atlas deployment
of f0adddd passed. Coordinated off-host snapshot fbbc8309 completed at 22:49 UTC:
53,727 files, 6.131 GiB. The repository check passed at 22:50 UTC and all three
applications and the updater timer are active. Its expanded restore is pending.

Lisa explicitly restored rules-and-philosophy posting and reactions on 19 October.
Its ordinary event levels are zero; moderator state and admission controls remain
unchanged. The first fifteen-room historical-reaction wave is complete: 716
messages, 2,392 reactor mappings, including 188 in rules. A reproduced rules
reaction passes at source power zero. Later rollout batches still need their
reaction passes. Ordinary admissions require role review; Space membership
grants no room access.

A fresh complete audit measures 300,499 root messages and 22,770,926,569 declared
ordinary attachment bytes across the remaining 30 readable text roots, plus 88
discovered public threads. The largest ordinary attachment is 502,648,947 bytes;
22 exceed 100 MiB. A parallel archive covers 29 roots and those threads alongside
the original whole-server export. Archives are not Matrix import proofs. Lisa
chose to keep four hidden text channels and all eight voice-channel text histories
excluded on 19 October; exact IDs are pinned in protected coverage-policy.json.
Unjoined private-thread history remains unavailable through the bot.

Source: [Discord reaction users and kinds](https://docs.discord.com/developers/resources/message#get-reactions).

Incremental rollout is authorized by Lisa's request to sync completed channels.
Verify each root export and every accessible public thread independently before
admission. Unused private rooms can be staged first; bind/import only after the
relevant source checks pass. Keep guild mode `if-portal-exists` throughout.

The history patch preserves pin, server-boost and channel-renaming system events
instead of silently omitting them. Moderation notice embeds use the rich-embed
converter to retain their description and fields. `retry-initial-backfill` is restricted to bridge admins in guild
portals and refuses any portal with an existing message mapping. It recovers a
completely failed empty import without deleting or replacing the room.
`import-thread-history THREAD_ID` likewise requires a bridge admin, verifies that
the accessible thread is public and belongs to this portal, requires its imported
root, and refuses threads with existing history. It reads archived history without
joining or unarchiving the Discord thread. Private threads require separate room
admission; this command deliberately refuses them.

Keep the ordinary event level at zero for bridge ghosts. Raising it globally to
50 blocks Discord authors as well as human members. Invitations/state changes
remain moderator-only; review each human account's channel read/post eligibility
before admission. Creating relay webhooks separately requires Manage Webhooks in
the individual Discord channel. A readable history room without that permission
is not evidence of a working relay for Matrix-only members.

`matrix.discord.readOnlyChannels` defaults to an empty list; Atlas has no read-only
channel exceptions following Lisa's revised instruction. If configured in future,
the bridge rejects Matrix-originated messages/edits, reactions and redactions for
those channels with a permanent permission failure, including queued sends.
Exclude PluralMatrix from such mirrors and assign individual readers power -1
before admission. Keep source ghosts at zero and administrators' management
rights intact; raising the global send level would block incoming source messages.
Restore the matching declarative policy when recovering the service.

Historical creation/backfill uses appservice-controlled Discord identities even
when an author has linked their real Matrix account. Ordinary Matrix account
tokens cannot preserve `origin_server_ts` in Synapse, and importing history must
not automatically admit those linked accounts. Live messages retain linked
identities; later Discord edits select the identity stored on the original part.
The source audit also identifies Discord's empty type-21 thread-starter wrappers:
DiscordChatExporter substitutes the referenced parent message's payload and ID.
Check that exact structural substitution against the API and parent export, retain
the actual wrapper ID/author/time, and import it as a linked structural notice.
Do not silently discard the wrapper or import the parent payload twice.

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

### Live media on Nook: deployed 2026-10-19

Lisa selected Nook's HDD for live Synapse media after the remaining attachment
audit exceeded Atlas's room for both live data and a full local backup copy.
Only media moves: PostgreSQL, signing keys, registrations and credentials stay
on Atlas. The existing local coordinated recovery copy stays on Atlas, providing
a separate physical copy from Nook's live media and encrypted backup repository.

`media.nix` prepares an NFSv4 export at
`/srv/disks/western-digital-hdd/matrix-media`. It binds Nook's tailnet address,
opens TCP 2049 only on tailscale0 and permits only Atlas's tailnet IP. Reserved
client ports are required. All NFS identities squash to the dedicated media UID
224. Disk-mount dependencies and a marker prevent exporting an empty root-disk
directory. A separate forced-command SSH account accepts the existing Atlas
backup key only from Atlas and only for restricted rsync within the media tree;
remote deletion and shell access are denied. The key remains agenix-managed.

The client uses an automount at Synapse's existing `media_store` path, hard NFS
mounts and a marker/filesystem guard before Synapse or checkpoint preparation.
An unavailable NAS must fail startup rather than write a local replacement.
Synapse and nginx accept 512 MiB uploads for the measured source files. The local
checkpoint fetches media through restricted SSH rsync to avoid per-file NFS
latency; its restore layout and full checksum manifest remain unchanged.

Cut over in two reviewed phases:

1. Deploy Nook with Atlas remote media disabled. Verify the HDD mount, free
   capacity, export, restricted transfers and independent backup reads. Do not
   enable the client before copying media.
2. Copy Atlas's current media into the export without deleting source files or
   the NAS marker. Verify file sizes and hashes. Wait for imports and coordinated
   checkpoints to finish, hold the auto-update timer, then pause Matrix, bridge
   and PluralMatrix for a final delta and verification. Keep services paused
   across activation so no process writes between the final copy and mount.
   The declarative service condition uses the root-only marker
   `/var/lib/sec-hive-migration/MEDIA-CUTOVER-PAUSED`; it also holds checkpoints
   and survives reboot. Clear it only after the final copy and mount are verified.
3. Enable the declarative Atlas client with the normal deployment script in
   maintenance mode. Retain the original local media underneath the mount for
   initial rollback. Confirm NFS and the marker before resuming services; verify
   existing authenticated media downloads, new uploads and unchanged content URIs.
4. Capture and restore-test an expanded coordinated backup before removing the
   old local media copy or importing the remaining large batch. Resume the
   auto-update timer after health checks. Record actual free space and headroom.

Before writes resume, rollback may unmount NFS and reveal the original local
media. After writes resume, reverse-copy new NAS media before reverting the
client; reverting the system generation alone would lose access to new files.
Nook preparation deployed as e2be06d; Atlas cut over as 8272c0d. All 53,688
frozen media files (5,185,486,008 bytes) have identical source/NAS SHA-256 sets.
Atlas's real Synapse UID passed a separate NFS read/write probe. All three
applications resumed on the NAS; five existing authenticated public URLs retain
their bytes, and a new 51 MiB public upload/download and its NAS file hash pass.
The original local media remains underneath the mount for initial rollback.

The first post-cutover coordinated backup, 789895a6, contains 53,729 files and
6.181 GiB. Its repository check passes. Restic restored and verified every file
from Nook; the isolated rehearsal passed at 23:29 UTC: 53,727 checkpoint hashes,
matching bridge/profile/backlog counts, all three applications started, and the
original pilot's 1,106 parts, 36 file hashes and 11 replies passed client checks.
The newly uploaded NAS file's restored 51 MiB hash also matches. External
networking was unavailable. Generated rehearsal copies were removed, the earlier
protected restore download retained, and Atlas's updater timer resumed. Atlas
has about 27 GiB free. The original 5.2 GB local duplicate remains pending Lisa's
cleanup decision; the full coordinated recovery copy remains on Atlas.

All thirty remaining root rooms are allocated privately without portals, Space
links or Lisa invitations. Their PluralMatrix allowlist is configured together so
later initial imports need no bridge restart per room. This is staging, not
verified history or live channel coverage. The four hidden roots and eight voice
text histories remain excluded. Two remaining roots have missing public-thread
starters and need explicit preservation handling before admission.

The `matrix-media` check passed on 19 October: real Synapse uploads/downloads, unauthorized
NFS peers, restricted rsync, unavailable storage, recovery and disk-mount lifetime
in isolated VMs. The 51 MiB upload crosses the old limit; its authenticated
download retains the same URI and bytes after an actual failed mount and recovery.

### Encrypted off-host repository

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

The fresh three-application snapshot `417849e0` was captured on 2026-10-18 at
14:21 UTC: 23,943 files, 2.046 GiB, 48.895 MiB additional stored data. Restic's
repository check passed. Synapse was inactive for 13.092 seconds; all applications
resumed before upload. The checkpoint contains two systems, two members, one
switch, 19 journal rows and zero pending Discord decision rows.

Restic downloaded and verified all 23,943 files from Nook into a new protected
input directory. The three-application rehearsal passed at 14:31 UTC in 72.575
seconds: 23,941 checkpoint content hashes, matching profile/journal/backlog and
bridge mapping counts, all three services started, and the original 1,106 message
parts, 36 attachment hashes and 11 reply relations passed client API verification.
External networking was unavailable. The first attempt exposed a captured systemd
PATH shadowing the verifier's binary paths; commit `8119c5f` preserves the verifier
PATH. The successful retry used the same verified off-host snapshot. Generated
restore databases/media and the superseded download were cleaned up; the newest
protected download, logs and result remain. Live services stayed active during
both rehearsals.
