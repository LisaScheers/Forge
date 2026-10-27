# SEC-Hive Matrix decommission

Lisa cancelled SEC-Hive Matrix hosting on 2026-10-27 and requested removal of its
rooms, files and backups. Discord must remain untouched. This replaces the earlier
migration and indefinite-sync plan.

The 74 remaining SEC-Hive channel, staging, operational and Space rooms have been
purged and blocked locally. Their events and native SEC guild mappings are gone;
46 unrelated Matrix rooms and historical Discord DM mappings are preserved. The
previously removed selfies room remains absent. Exclusive media and cached room
data cleanup is still in progress.

The SEC bot login has been removed from the local bridge database. This did not
call Discord logout, webhook deletion or server/channel APIs. The shared bridge
and PluralMatrix remain stopped during media cleanup. The replacement configuration
disables PluralMatrix and removes SEC's cutoff, allowlist and relay admin grant;
shared Synapse, PostgreSQL, Discord appservice and live media volume remain.

Lisa answered the mixed-backup question with “preserve no backup.” Remove all
Matrix backup snapshots, archives, coordinated staging and restore copies; do not
create a replacement. Disable the Matrix backup job and exclude the three Matrix
databases from future global PostgreSQL dumps. Preserve other-service backup data
and unrelated live Matrix data. Generic backup/restore tooling may remain dormant.

Eight local raw export trees have been removed (168,636 regular files,
133,622,774,531 logical bytes; cloned copies mean this is not reclaimed disk space).
Encrypted test recovery images and keys were removed. Three SEC-only snapshot
references were forgotten; physical repository removal and all other Matrix
backup deletion are in progress. Completion requires verification of absent
SEC rooms, exclusive media, local payloads, credentials and backup data.
