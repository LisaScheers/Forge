# SEC-Hive Matrix decommission

SEC-Hive Matrix hosting was cancelled and removed on 2026-10-27. Discord itself
was not modified. This page records what stays in place and why.

## What Atlas keeps

`checks.matrix-atlas` (`modules/services/matrix/atlas-test.nix`) asserts each of
these:

- Synapse, PostgreSQL and the generic Discord bridge, with Lisa as bridge admin
  and no SEC-Hive relay account. The six mapped Discord DM rooms and unrelated
  Matrix rooms remain.
- Synapse's media on Atlas's dedicated volume.
- Global PostgreSQL backups that exclude `matrix-synapse`, `mautrix-discord` and
  the old `pluralmatrix` database. Lisa chose to keep no Matrix backup; every
  other service's database is still backed up (`checks.matrix-backup-exclusion`).

## What was removed

All SEC-Hive rooms, their media and service accounts, PluralMatrix, the
coordinated Matrix backups and their credentials, Nook's remote-media and backup
endpoints, and the bridge's SEC-Hive media-retention feature. Blocks keep the
removed room IDs from being recreated locally. The removal was deployed from
`49419f2`; later commits deleted the code that was left disabled.
