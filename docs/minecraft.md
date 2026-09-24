# Minecraft

ATM 10 runs on Nook as `atm10-8-0.service`, using
`/var/minecraft/atm10-8.0`. Its Java heap is 8–15 GiB; the service allows
additional memory for Java's native allocations.

Atlas retains public TCP port 25565 and forwards connections over Tailscale to
Nook at `100.106.233.104:25565`. RCON is not exposed publicly. The proxy does not
preserve client IP addresses; Minecraft's online-mode authentication remains
enabled.

The migration retained the stopped server directory on Atlas as a rollback
copy. It is not a current backup after players resume on Nook. Never start both
copies: before moving back, stop Nook and copy its current data to Atlas.

Deploy changes with the host-specific recipes in the README. Atlas's Minecraft
unit is disabled declaratively to prevent automatic updates from starting the
old world. Atlas also has an 8 GiB swap file for shared-service memory spikes.
