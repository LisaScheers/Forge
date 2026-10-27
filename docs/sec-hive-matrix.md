# SEC-Hive Matrix decommission

Lisa cancelled SEC-Hive Matrix hosting on 2026-10-27 and requested removal of its
rooms, files and backups. Discord must remain untouched. This replaces the earlier
migration and indefinite-sync plan.

The 74 remaining SEC-Hive channel, staging, operational and Space rooms have been
purged and blocked locally. Their events and native SEC guild mappings are gone;
46 unrelated Matrix rooms and historical Discord DM mappings are preserved. The
previously removed selfies room remains absent. SEC media/profile cleanup and
mixed historical backup handling are still in progress.

PluralMatrix is disabled. The shared Discord appservice, Synapse, PostgreSQL,
Nook backup/media endpoints and Matrix volume remain for unrelated use. SEC's
cutoff, room allowlist and dedicated relay administrator grant are removed.
The SEC bot login must be removed locally before the shared bridge resumes;
removal must never call Discord logout, webhook deletion or server/channel APIs.

Generic coordinated backups no longer depend on SEC migration files. Optional
`matrix.backup.historyVerificationDirectory` defaults to `null`. Without an
explicit history account/manifest, restore checks still verify complete checksums,
databases, bridge mappings/tokens, signing key, copied media and isolated startup.
Generated SEC proof copies and disabled Plural staging artifacts are cleared before
new captures.

Keep shared assets and unrelated recovery data. Old whole-homeserver snapshots
contain both SEC-Hive and unrelated history; discarding those restore points needs
Lisa's explicit choice, otherwise sanitization must preserve unrelated data.
