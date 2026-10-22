# Minecraft

Nook's Minecraft services use its Kingston SSD and are manual-only:

| Service | Pack | Directory under `/srv/disks/second-life-cache/minecraft` |
| --- | --- | --- |
| `atm10-8-0` | All the Mods 10 8.1 (original world) | `atm10-8.0` |
| `atm10-aero` | All the Mods 10 Aeronautics 0.7.1 | `atm10-aero-0.7.1` |
| `ftb-skies-2-aero` | FTB Skies 2: Aero 1.13.0 | `ftb-skies-2-aero-1.13.0` |

FTB Skies 2: Aero first started at Lisa's request on 2026-10-20; ATM10 Aero
has never been started. Both use Minecraft 1.21.1, NeoForge
21.1.250 and Nix-provided Java 21, with an 8–15 GiB heap and 20 GiB service
memory limit. Dedicated service users own each installation. A `.prepared`
marker gates startup. Neither unit is wanted by a boot target; starting one
stops the other because they share TCP 25565. RCON is disabled. Existing
operator identities were retained; no old world or extra mods were copied.

Do not start either Aero server until Lisa requests it. Start exactly one pack:

```sh
ssh nook sudo systemctl start atm10-aero.service
# Or: ssh nook sudo systemctl start ftb-skies-2-aero.service
# Original world: ssh nook sudo systemctl start atm10-8-0.service
```

FTB Skies 2: Aero generated its new world and reported ready at 14:40:17
Europe/Brussels on 2026-10-20. Direct Nook and `mc.bylisa.dev:25565` status
requests returned Minecraft 1.21.1, protocol 767; both ATM10 services were
stopped. Joining and island generation have not been tested.

## Original ATM10 world recovery, 2026-10-20

Lisa chose to restore the original ATM10 8.1 world, rather than start an Aero
world. Recovery uses `atm10-8.1-current.tar` below, extracted with GNU tar's
`--acls --xattrs --numeric-owner` into the original SSD location. Compare the
restored tree against the archive before changing ownership to `atm10-8-0`.
Keep the retirement archive intact.

The full archive comparison passed. Minecraft reported ready at 12:51:41
Europe/Brussels; both direct Nook and `mc.bylisa.dev:25565` status requests
returned Minecraft 1.21.1, protocol 767, with zero players. Both Aero services
remained stopped.

The restored service launches the saved installation directly, preserving its
mods, settings, JVM arguments, operators, RCON configuration and ComputerCraft
programs. It requires `world/level.dat`, preventing accidental world creation.
It conflicts with both Aero services and uses Java 21 with the saved 8–15 GiB
heap and a 20 GiB service memory limit.

The recovery installs only the Nix-built service at runtime; no older whole
system configuration is activated. Its dependencies are retained by
`/nix/var/nix/gcroots/atm10-restored-service`. The declarative definition is in
`modules/services/minecraft/server.nix`. Until that definition is deployed,
the runtime unit disappears on reboot; it can be relinked with:

```sh
ssh nook sudo systemctl link --runtime /nix/var/nix/gcroots/atm10-restored-service/atm10-8-0.service
ssh nook sudo systemctl daemon-reload
ssh nook sudo systemctl start atm10-8-0.service
```

## ATM10 retirement, 2026-10-18

ATM10 8.1 (`atm10-8-0.service`) was shut down cleanly before backup. Its retired
service definitions and the unused ATM10 TTS, ATM10 6.6, ATM11, Cutie Craft,
CUS2 and All the Mons definitions were removed from Nook's module.

Backups are private to root on Nook's HDD:

`/srv/disks/western-digital-hdd/minecraft/backups/retirement-2026-10-18/`

- `atm10-8.1-current.tar`: full final SSD installation, including world,
  players, ComputerCraft programs, mods, configuration and local backups.
  GNU tar comparison against the stopped source verifies contents and
  metadata; `SHA256SUMS` records the archive checksum.
- `atm10-8-0.service.txt`: the former effective service definition.
- `rcon.password`: retired root-owned RCON credential; restore to the path
  in the old unit when recovering ATM10. Neither Aero server uses it.
- `stale-hdd-atm10-8.0/`: earlier HDD rollback installation, stale since the
  2026-10-02 SSD migration.
- `stale-var-atm10-8.0/`: earlier `/var/minecraft` rollback installation;
  world, mods and settings retained and checksum-compared. Generated BlueMap
  render cache omitted from this older copy.
- `atlas-retired-minecraft.tar.zst`: Atlas's entire retired `/var/minecraft`
  tree (ATM10 7.0, 7.2 and 8.0, All the Mons, Cutie Craft and old backups).
  Streamed directly to Nook. Source and archive manifests compare every file's
  SHA256, path, type, mode, numeric owner/group, mtime, symlink target and xattrs.
  Both manifests and the verification helper are saved under `staging/`.
  The original tree is removed only after comparison succeeds.
- `staging/`: original Aero ZIPs and installation logs.

The old SSD working directory is removed only after the final backup passes
comparison. The stale installations are preserved under the backup directory,
not used as active server roots. Restore the final archive when recovering
current play; the stale copies do not contain later progress.

To restore, keep both Aero services stopped, extract the archive into an
empty recovery directory with GNU tar (`--acls --xattrs --numeric-owner`),
and restore the old service configuration from Git history. Review ownership,
paths and credentials before starting. Do not start multiple world copies.

The Minecraft-only activation uses the exact deployed baseline, Forge
`579be0d`, plus `modules/services/minecraft/server.nix`, to avoid applying the
newer system dependencies in the current checkout. The same Minecraft module
is saved in the current checkout for future deployments.

## Installation sources

Original ZIPs remain in Lisa's Downloads directory:

- `ATM10AERO-0.7.1-server.zip`, SHA256
  `728195644be4c103057bf763b710c960cff4042b250971253aa9d9a8e031ccf0`.
  Its launcher supports `ATM10_INSTALL_ONLY=true`; this installs NeoForge
  without launching Minecraft.
- `ftb-skies-2-aero-1.13.0-server.zip`, SHA256
  `516244c86f85360f5bc46400dedaaee6477039fa9e202240990db84e1622ab06`.
  Contains download scripts only. Official FTB installer: pack `134`, version
  `100527`, `-auto -no-java`; downloads pack files and installs NeoForge using
  Java from a temporary Nix environment. The installer does not start Minecraft.

## Connection routing

The existing address is `mc.bylisa.dev:25565`. Nook's Cloudflare DDNS updater
maintains DNS-only A and AAAA records. UniFi forwards WAN1 TCP 25565 to
`192.168.111.2:25565`; its `Minecraft ATM10 IPv6` firewall rule allows the same
port to `2a02:1810:515:c680:f22f:74ff:fe1d:7b9b`. Update that rule if the ISP
changes Nook's IPv6 prefix.

Atlas also forwards public TCP 25565 over Tailscale to
`100.106.233.104:25565`. It does not preserve client IP addresses; Minecraft
online-mode authentication stays enabled. Atlas's old ATM10 server remains
masked; its historical server files are archived on Nook's HDD.
