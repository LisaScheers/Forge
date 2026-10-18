# SEC-Hive: Discord ↔ Matrix

Target: Shiny Entity Collection (SEC-Hive). Both platforms remain equal indefinitely.
History: all accessible messages and attachments. An external export does not replace
the required Matrix import.

Discord application: `1561338659536375828` (SEC-Hive Matrix Bridge). Server Members
and Message Content intents enabled. No personal Discord account tokens.
Guild ID: `1293572131086667827`. Lisa confirmed the bot was added on 2026-10-18.
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
No Matrix portals, service deployment, or live relay have been performed.

Checks: migration package builds and its 4 permission/attachment tests pass;
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
```

`inventory.json`: guild/channel/role metadata, effective bot access, active threads,
and initial channel mapping. The exporter enumerates active and archived threads
with `--include-threads All`, downloads assets, and preserves message IDs in JSON.
Inaccessible private threads still require an explicit coverage report.

`verification.json`: export counts, attachment sizes/SHA-256, missing local files,
and missing accessible message-channel exports. This checks local integrity; it
does not establish full source coverage, forum coverage, or successful Matrix import.
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

- Finish inventory/export and verify the history bound; no recent-history fallback.
- Federation enabled and encryption disabled are confirmed. `federateRooms = false`
  is only for disposable local pilot rooms; a permanent room cannot later be made
  federated by changing this flag. Confirm history visibility, membership, and
  moderator powers.
- Prove webhook relay from ordinary members; test edits/deletions, attachments,
  threads/forums, other webhooks, and reconnect/catch-up behavior.
- Import into unused rooms before inviting members. Synapse cannot insert old
  messages into the middle of an existing conversation.
- Preserve channel/guild history if Discord channels are removed or the bot leaves.
- Test a coordinated restore of Synapse data/media/signing keys plus bridge state.

Voice/video, permission synchronization, moderation, and Discord-only bots require
separate workflow verification; ordinary text bridging is not evidence of parity.

## Production deployment

Use Forge's normal Atlas deployment gate. It requires a clean checkout whose HEAD
matches `origin/main`, builds the three target checks, and coordinates the updater.
Do not deploy unrelated working-tree changes or bypass the gate.

PostgreSQL backups already include all databases. They do not cover Synapse media,
signing keys, bridge registration/credentials, or off-host recovery by themselves.
