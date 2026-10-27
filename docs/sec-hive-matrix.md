# SEC-Hive Matrix decommission

Completed 2026-10-27 after Lisa cancelled SEC-Hive Matrix hosting. Discord was not
modified. The migration and indefinite-sync plan are cancelled.

- All 75 SEC-Hive rooms/Spaces, including the previously removed selfies room,
  are gone. Their content is absent across all 65 Synapse tables with room IDs;
  intentional blocks prevent those room IDs from being recreated locally.
- Removed 198,219 live files (43,820,878,253 bytes); all 39,305 selected media IDs
  return authenticated 404. Verified 24,346 unrelated files by hash.
- Removed local exports, migration working copies, PluralMatrix database/state,
  registration files and credentials. Seven SEC service accounts were erased
  and deactivated, with all access tokens revoked.
- Removed all Matrix snapshots, recovery/staging copies and Nook's retired media
  duplicate. Removed Matrix sections from both combined PostgreSQL backups while
  preserving other services' sections byte for byte.

Lisa explicitly chose “preserve no backup.” Matrix backup jobs, restore services,
credentials and recovery bind are disabled/removed. Global PostgreSQL backups
exclude `matrix-synapse`, `mautrix-discord` and `pluralmatrix`; other services'
backups continue. Nook's dedicated Matrix storage endpoints and keys are removed.

The shared homeserver, live Atlas media volume, generic Discord appservice,
46 unrelated Matrix rooms and six mapped Discord DM rooms remain. Synapse,
PostgreSQL, nginx and the generic bridge are healthy; the public Matrix endpoint
returns HTTP 200. Configuration was deployed from `49419f2` on Atlas and Nook.
