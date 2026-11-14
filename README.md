# Forge

## About

This flake manages Nook, Atlas, Vega, and Asterion. Altair no longer exists and is not a flake output.

[Asterion](docs/asterion.md) is the installed Asahi configuration for the
16-inch M3 Pro MacBook Pro, with a dedicated live installer image. Installation is
manual; it is not part of the server deployment or automatic update paths.
Encrypted boot, the native Niri/Noctalia desktop, GPU acceleration and protected
speaker playback are verified on the installed system.

## Architecture

Every Nix file under `modules/` is a top-level flake-parts module, loaded by
[import-tree](https://github.com/denful/import-tree). A feature can contribute
system settings, home settings, packages, checks, and inputs together.

`nixos`, `darwin`, and `home` are class-checked deferred-module options.
Features merge into named profiles such as `nixos.nook`, `darwin.vega`,
`home.lisa-cli`, and `home.lisa`. The CLI profile supplies shared shell and home
integration dependencies; Lisa's main profile adds her usual applications.
Asterion selects Lisa's portable profile and its own desktop settings.

The layout follows the feature-oriented structure in Rose's and Esmee's
configurations and [Vimjoyer's examples](https://vimjoyer.com/nix/):

| Directory | Contents |
| --- | --- |
| `modules/flake/` | Inputs, profile types, package sets, checks, CI, deployment |
| `modules/hosts/<host>/` | Host output, explicit profile selection, machine settings |
| `modules/homes/lisa/` | User profiles and standalone Home Manager outputs |
| `modules/shell/` | Git, Bash, Zsh, Nushell, prompts, direnv, package lookup |
| `modules/development/` | Editors, AI tools, development shell, local helpers |
| `modules/desktop/` | Terminal, theme, fonts, desktop settings |
| `modules/services/<feature>/` | Related server, authentication, proxy, or collector pieces |
| `modules/security/` | Agenix, SOPS, SSH, GnuPG, 1Password |
| `modules/hardware/` | Host hardware, disk support, Apple Silicon installers |
| `packages/` | Raw package recipes and patches; outside automatic loading |

Each host's `default.nix` constructs its NixOS or Darwin output and visibly
selects hardware and Home Manager profiles. Home files construct standalone
outputs using the same home profiles and the shared per-system package set.
There is no host registry or automatic home registration. For example, Nook's
host module binds `home-manager.users.lisa = config.home.lisa-nook`.

Adding settings to an existing profile requires no file import-list edit.
Distinct reusable profiles are selected explicitly by name. Selecting a feature
enables it by default; existing opt-outs remain available. The unselected
`home.lisa-proxy` profile keeps Lisa's local proxy disabled.
`flake.modules` publishes the named profiles for external consumers.

`flake-file` generates `flake.nix` from feature-owned input declarations.
Regenerate it with `nix run .#write-flake`. The root entry point imports
`modules/` directly. `modules/security/agenix/_secrets.nix` is the standalone
agenix CLI entry point and reads the flake's `agenixRules` output. The underscore
keeps it out of automatic loading. The `dendritic` and `profiles` checks enforce
top-level feature boundaries and module-class safety.

CI targets are declared beside their host, home, or installer output. The CI
module maps those declarations to native runners without evaluating host builds.

Hardware regeneration writes `modules/hardware/<host>.nix`. Save the target's
`nixos-generate-config --show-hardware-config` output locally, then run
`just hardware-config nook /path/to/hardware-configuration.nix` and review it.
The helper wraps the generated configuration in `nixos.<host>-hardware`.

## Package lookup

[Aurora Viewer on macOS](docs/aurora-viewer.md) documents Vega's source-built
Second Life viewer, its Metal port, and the current validation limits.

The shared shell composition installs `nix-locate` and comma (`,`), backed by the
locked [nix-index-database](https://github.com/nix-community/nix-index-database)
input. No local database generation is needed. Bash, Zsh, and enabled Nushell
sessions suggest packages when a command is missing.

```sh
nix-locate --whole-name bin/dig
, --print-packages dig
, dig example.org
```

The database follows upstream's nixos-unstable package index; a result can differ
from Forge's pinned Nixpkgs master revision. Update it with
`nix flake update nix-index-database` and apply the configuration normally.

## Git authentication

Home Manager configures GitHub and Gist to use `gh auth git-credential`.
For `git.bylisa.dev`, Git uses the login stored by `fj`. Since forgejo-cli 0.7
has no Git credential-helper command, a small adapter lets `fj` refresh its
OAuth login before reading the saved token. Tokens stay in each CLI's own store.

After applying this configuration, sign in with the CLIs if needed:

```sh
gh auth login --hostname github.com
fj --host https://git.bylisa.dev auth login
forgejo-api user
forgejo-api repos/Lisa/STSTP-Controller
```

For writes, pass `-X POST` (or another method) and `-d '{"name":"example"}'`;
`-d -` reads JSON from stdin. `forgejo-api` gets its credential through Git too.
A permission error does not discard the saved login or automatically open another
sign-in window.

## Atlas honeypots

`modules/services/honeypot.nix` imports the public
[`nix-honeypot`](https://github.com/LisaScheers/nix-honeypot) flake and enables
SSH, HTTP, FTP and Redis decoys on Atlas. Their TCP ports are 2223, 8080, 2121
and 6380 respectively, opened by the NixOS firewall. The SSH and Redis overrides
avoid Forgejo SSH on 2222 and Authentik Redis on 6379. Administrative SSH keeps
its existing configuration.

The decoys capture credentials and application payloads in private, rotated
JSONL files under `/var/log/honeypot`. Run `sudo honeypot-report` on Atlas for
connection counts, source addresses and event summaries. Captured commands use
inert responses; they never execute on the host. The default limits are 256 KiB
of payload per connection, a 120-second session lifetime and approximately
128 MiB of retained logs. Copy evidence before rotation for longer retention.

## Deployment

Deployments use the locked `deploy-rs` input. Run the server commands from Vega, where the SSH aliases and builders are configured. Every command names one host; there is no fleet-wide deployment recipe.

```sh
just deploy-build nook
just deploy nook dry
just deploy nook test
just deploy nook
```

Use the same commands for Atlas. The Atlas recipe refuses dirty or off-main revisions, aborts when an auto-update or scheduled reboot is active, and pauses `nix-auto-sync-update.timer` while deploy-rs runs. It restarts the timer after a successful deployment or a preflight abort. If deploy-rs itself fails, the timer stays stopped so it cannot retry the same bad `main` revision; the recipe prints the recovery command.

For an approved database maintenance window, `just deploy-maintenance` applies
Atlas while leaving its updater timer stopped. The root-owned marker
`/var/lib/postgresql/.forge-maintenance` also prevents updater runs across
reboots. Keep the marker and timer hold until migration and recovery checks pass;
then remove the marker and restart `nix-auto-sync-update.timer` explicitly.
Atlas's PostgreSQL major and data directory are pinned in
`modules/services/postgresql/atlas.nix`. Its scheduled `pg_dumpall` backup covers
all databases and cluster roles, with the existing Uptime Kuma completion probe.
Atlas uses PostgreSQL 18 at `/var/lib/postgresql/18`. Startup requires its
`PG_VERSION` and `.forge-upgrade-complete` marker; create the marker only after a
successful `pg_upgrade` or a verified full restore. Keep the PostgreSQL 16
directory and its system generation for recovery. Returning to it after new
writes requires reconciling those writes or restoring a current backup.
The `nixpkgs-atlas-apps` and `nixpkgs-nook-apps` inputs track Nixpkgs master
for Forgejo, Home Assistant and Sonarr. Their migration holds were removed after
Lisa confirmed migration and recovery checks were complete on 8 November 2026.
Their lock entries still allow application updates separately from infrastructure.

The recipe builds the host closure plus host-specific deploy-rs schema and activation checks before it opens the deployment connection. Nix may still use the remote builders declared by this flake during that build. The recipe then passes `--skip-checks` to deploy-rs because Forge's full-flake check has pre-existing development-shell check failures. Do not use `--skip-checks` without those targeted builds.

Atlas needs one bootstrap from its existing auto-updater after this change reaches `main`. That activation adds `lisa` to Nix's trusted users. Confirm it before the first deploy-rs run:

```sh
ssh atlas 'nix config show trusted-users'
```

Asterion also supports manual remote deployment from Vega:

```sh
just deploy-build asterion
just deploy asterion dry
just deploy asterion test
just deploy asterion
```

Its deploy-rs node connects as `root` to the SSH hostname `asterion`, using the
existing Vega management key authorized by its configuration. Configure that
hostname and file key in your SSH client and confirm `ssh root@asterion true`
works first; disable the SSH agent for this file key. An `aarch64-linux` builder
is required. Reboot after kernel, GPU driver, Mesa or boot firmware changes;
see the [Asterion guide](docs/asterion.md).

Vega and Asterion also support local manual switches. On either host, run:

```sh
just switch
```

On Asterion, this runs `sudo nixos-rebuild switch` using this checkout in the
current terminal. Reboot after kernel, GPU driver, Mesa or boot firmware changes;
see the [Asterion guide](docs/asterion.md).

On Vega, this opens Apple Terminal and switches Vega using this checkout. Enter your sudo
password or use Touch ID there. The command in Zed returns when Terminal opens;
the activation result appears in Terminal. No prior rebuild is needed to use it.

If prompted, enable **Terminal** in **System Settings → Privacy & Security →
App Management**, then rerun `just switch`. Nix-built Zed Nightly can change its
code-signing identity after updates, invalidating its macOS permissions. Running
activation in Apple's signed Terminal keeps that permission independent of Zed.
Directly running `sudo darwin-rebuild switch` inside Zed still uses Zed's permission.

For Nix cleanup on Vega, run `just clean`. This opens Apple Terminal and runs
`sudo nix-collect-garbage --store local -d`, deleting old profile generations and
collecting unused store paths. Enter your sudo password or use Touch ID there;
the cleanup result appears in Terminal. No rebuild is needed to use this command.
If cleanup fails with `chmod '…app': Operation not permitted`, enable Terminal
under **System Settings → Privacy & Security → App Management** and rerun it.
The explicit local store keeps cleanup under Terminal's app permission rather
than forwarding it to the background Nix daemon. Vega's Lix defaults to the
daemon even under sudo, so the original `sudo nix-collect-garbage -d` can fail
on protected app bundles even inside Terminal with App Management enabled.

Vega's optional deploy-rs node points to `localhost` and uses interactive sudo.
Bootstrap its SSH configuration once, then build and deploy it:

```sh
just vega-bootstrap
ssh -o BatchMode=yes localhost true
just deploy-build vega
just deploy vega
```

`just vega-bootstrap` opens the same Terminal switch command. The deploy-rs path
uses SSH instead; nix-darwin requires **Allow full disk access for remote users**
under **System Settings → General → Sharing → Remote Login** for app updates over
SSH. `just switch` uses the local graphical session and needs no SSH setup.

Do not use deploy-rs dry, test, or boot modes for Vega. The nix-darwin activator in the pinned deploy-rs revision does not implement those modes as real activations.

Keep console access available for the first deploy-rs activation on every host. The generation installed before deploy-rs does not contain its rollback wrapper. Later activations use automatic and connection-confirmed rollback with a 10-minute activation timeout and a 60-second confirmation timeout.

## Continuous integration

GitHub Actions updates `flake.lock` daily at 00:00 UTC and opens or refreshes an
update PR. The repository must allow GitHub Actions to create pull requests
(Settings → Actions → General → Workflow permissions).

The `FLAKE_INPUTS_TOKEN` Actions secret supplies Nix with GitHub read access to
the private `LisaScheers/comic-code-fonts` input for builds and lock updates.
Fork pull requests do not receive this secret and cannot build the private input.

The update workflow builds the PR's exact commit directly, because PRs created
with `GITHUB_TOKEN` do not trigger other workflows. Its PR body links to the build
results. The same build workflow runs for ordinary PRs, pushes to `main`, and
manual runs.

Both workflows use Lix, matching the hosts and preserving the tarball revision
URLs in Lix-generated lock files. Upstream Nix 2.35 rejects those URLs during
configuration evaluation.

The build matrix discovers every NixOS, nix-darwin, and standalone Home Manager
configuration from the flake and builds it on a native Linux or macOS runner.
It also builds both Asterion installer packages. These are full builds, with
lock-file changes disabled. CI does not activate configurations or deploy hosts.

## References

1. Module classes use [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
2. Recursive loading uses [denful/import-tree](https://github.com/denful/import-tree)
3. Deployments use [serokell/deploy-rs](https://github.com/serokell/deploy-rs)
