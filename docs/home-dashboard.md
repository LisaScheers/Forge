# Home dashboard

https://dash.bylisa.dev runs on Atlas. The Cosmic launcher layout uses local SVG
icons, service cards, search, an issues filter, and expandable check details.

Anonymous visitors see the personal site and publicly browsable Forgejo.
Authentik users also see media, home automation, identity, monitoring, mail,
Minecraft, and every remaining non-group Uptime Kuma check. Application-specific
permissions still apply when opening a service. Home-only links are labeled
“Home / Tailscale”. Minecraft offers a copyable server address.

`services/home-dashboard/catalog.json` owns service navigation and visibility.
Visibility defaults to private; only entries with `public: true` are exported
anonymously. Disabled Mastodon is excluded. A public login page alone does not
make an application's functionality public.

The Nix module in `flake-parts/hosts/atlas/home-dashboard.nix` owns nginx, TLS,
the Authentik provider, the API, and a 30-second status timer. Authentik's embedded
outpost authenticates `/api/private` and `/login`. The API listens only on a Unix
socket; nginx overwrites its identity header. Neither private links nor private
status counts appear in public HTML or public API responses. Private data is
never cached. Signing out goes through the outpost's sign-out flow.

The collector reads Kuma's SQLite database in read-only mode. It selects only
monitor names, active flags, timing configuration, and heartbeat status/time/ping;
it never exports credentials, push tokens, URLs, heartbeat messages, or saved
responses. The API cannot open Kuma's database. It reads reduced snapshots only.
Existing Kuma monitor names map checks to cards; remaining checks appear under
Infrastructure privately. Kuma remains the alerting source for its own monitors.

Additional HTTP reachability checks cover the site, Element, Seerr, Uptime Kuma,
the movie-night console, and Transmission. Nook's local HTTPS hosts are reached
over Tailscale while verifying certificates against their original names.
Authenticated HTTP responses and Transmission's expected 409 establish
reachability, not successful login or full user workflows. Check details label
the measurement type. Dashboard-only probes do not configure Kuma alerts.

Any failed component marks its card unavailable. Missing or stale heartbeats
become Unknown, retrying checks stay Retrying, and paused/maintenance states are
preserved. Push freshness follows the configured deadline, including day-long
backup jobs. Snapshots older than two minutes become Unknown. Browser refreshes
every 30 seconds and on returning to the tab. Failed session checks clear private
data from the current view.

Deploy through `just deploy atlas` from clean `origin/main`, as documented in
the repository README. No Nook deployment is required.

Run the narrow status tests with a Nix Python runtime:

```sh
nix shell nixpkgs#python3 -c python3 -B -m unittest discover -s services/home-dashboard
node --check services/home-dashboard/public/dashboard.js
```
