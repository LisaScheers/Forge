# Home media access

Nook serves Jellyfin through nginx. `jellyfin.bylisa.dev` is the public
hostname; `jellyfin.local.bylisa.dev` and `media.local.bylisa.dev` remain local
aliases. Nix manages the public Cloudflare DNS record, ACME certificate, and
HTTPS virtual host in `flake-parts/hosts/nook/media.nix`.

The UniFi gateway already forwards public TCP ports 80 and 443 to
`192.168.111.2`. The public route was verified from Atlas on 2026-09-17 using
the local Jellyfin hostname and the gateway's public IPv4 address. The new
public hostname still needs deployment and end-to-end verification.
The existing DNS updater publishes both A and AAAA records. Atlas has no IPv6
route, so external IPv6 access was not verified. Before rollout, review the
UniFi `http/s ipv6` rule: its destination observed on 2026-09-17 was
`2a02:1810:515:c680:9140:eac1:12:572c`, whereas Nook currently uses
`2a02:1810:515:c680:f22f:74ff:fe1d:7b9b`.

Friends use separate Jellyfin accounts with remote access and the intended
libraries enabled. No VPN client is required. Account creation and playback
with a friend account still need verification. nginx is registered as a known
proxy so Jellyfin can distinguish remote clients.

## Local DNS and UniFi

UniFi's `adblock` content-filter policy covers `main LAN`, where Vega lives.
It redirects DNS requests to the gateway, including requests explicitly sent
to Nook. Nook's Unbound zone is correct, but the gateway's existing
`local.bylisa.dev` A record does not forward subdomain queries.

The required gateway setting is **Policy Engine → Policy Table → Create New
Policy → DNS → Forward Domain**:

- Domain: `local.bylisa.dev`
- DNS server: `192.168.111.2`

This setting was saved with Lisa's approval on 2026-09-17 and is managed in
UniFi, outside this flake. It preserves ad blocking. Gateway A/AAAA answers and
Vega's native resolver were verified; Sonarr HTTPS returned its expected 401.
Vega may retain earlier negative lookups until its DNS cache expires.
See [Ubiquiti's local DNS forwarding guidance](https://help.ui.com/hc/en-us/articles/12568927589143-Content-and-Domain-Filtering-in-UniFi).

After saving, verify on Vega with `dscacheutil -q host -a name
jellyfin.local.bylisa.dev` and an HTTPS request to that hostname. Direct DNS
queries alone do not verify the macOS application resolver.

Deploy only with Lisa's approval and from `origin/main`, following the
repository deployment instructions. After deployment, verify the public
hostname's DNS, TLS certificate, login, and movie playback from an external
connection.
