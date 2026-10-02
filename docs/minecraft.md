# Minecraft

ATM 10 runs on Nook as `atm10-8-0.service`, using
`/srv/disks/second-life-cache/minecraft/atm10-8.0` on the Kingston SSD. Its Java heap is 8–15 GiB; the service allows
additional memory for Java's native allocations.

Inactive Nook Minecraft packs and upgrade backups use the HDD's
`/srv/disks/western-digital-hdd/minecraft` directory. ATM 10 requires both mounts
before starting; the other packs require the HDD.
ATM 10 refuses to start without its existing installation, preventing an
empty world from being created before data is migrated.

For the SSD migration, pause Nook's automatic update timer and stop
`atm10-8-0.service`. Confirm the SSD is mounted, then copy the existing
`/srv/disks/western-digital-hdd/minecraft/atm10-8.0/` installation to
`/srv/disks/second-life-cache/minecraft/atm10-8.0/` with
`rsync -aHAX --numeric-ids` as root. With the server still stopped, verify the
copy with `rsync -aHAXnc --numeric-ids --delete --itemize-changes` (no output),
then deploy the approved revision from `origin/main` using the README recipe.
Confirm the server starts from the SSD and players can join before resuming
automatic updates. Retain the HDD installation and the older `/var/minecraft`
copy for rollback until separately approved for deletion. They become stale
once players resume; copy the current world back before using either one.

Players can connect directly through `mc.bylisa.dev:25565`. Nook's Cloudflare
DDNS updater maintains DNS-only A and AAAA records. UniFi forwards WAN1 TCP
25565 to `192.168.111.2:25565`; its `Minecraft ATM10 IPv6` firewall rule allows
the same port to `2a02:1810:515:c680:f22f:74ff:fe1d:7b9b`. Update that rule if
the ISP changes Nook's IPv6 prefix.

Atlas retains its old public TCP port 25565 and forwards connections over Tailscale to
Nook at `100.106.233.104:25565`. RCON is not exposed publicly. The proxy does not
preserve client IP addresses; Minecraft's online-mode authentication remains
enabled.

The migration retained the stopped server directory on Atlas as a rollback
copy. It is not a current backup after players resume on Nook. Never start both
copies: before moving back, stop Nook and copy its current data to Atlas.

Deploy changes with the host-specific recipes in the README. Atlas's Minecraft
unit is disabled declaratively to prevent automatic updates from starting the
old world. Atlas also has an 8 GiB swap file for shared-service memory spikes.
