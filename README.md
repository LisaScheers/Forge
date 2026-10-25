# Forge

## About

This flake manages Nook, Atlas, and Vega. Altair no longer exists and is not a flake output.

[Asterion](docs/asterion.md) is the experimental Asahi configuration for the
16-inch M3 Pro MacBook Pro, with a dedicated installer image. Installation is
manual; it is not part of the server deployment or automatic update paths.
Encrypted console boot is verified. Native niri remains blocked by M3 graphics
support; the Home Manager desktop configuration is provided for future use.

## Architecture

Every Nix file under `modules/` is a top-level flake-parts module, loaded by
[import-tree](https://github.com/denful/import-tree). A feature can contribute
system settings, home settings, packages, checks, and inputs together.

`nixos`, `darwin`, and `home` are class-checked deferred-module options.
Features merge into named profiles such as `nixos.nook`, `darwin.vega`,
`home.lisa-cli`, and `home.lisa`. The CLI profile supplies shared shell and home
integration dependencies; Lisa's main profile adds her usual applications.
Asterion selects the CLI profile and its own desktop settings.

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

## Forgejo authentication

Git and `forgejo-api` share the credential helpers configured by Home Manager.
On macOS, Keychain stores both access and refresh tokens; Linux currently uses
Git's six-hour memory cache. The OAuth grant includes `write:repository` and
`write:user`, which is also required to create a repository through `/user/repos`.
The shared grant uses Forgejo's built-in `tea` public client. Forgejo rejects scope
changes on an existing grant, so it is separate from the old Git-only grant.

After applying this configuration, authorize the expanded grant once:

```sh
forgejo-api login
forgejo-api user
forgejo-api repos/Lisa/STSTP-Controller
```

Before activation, use `nix run .#forgejo-api -- login` from this checkout.
For writes, pass `-X POST` (or another method) and `-d '{"name":"example"}'`;
`-d -` reads JSON from stdin. The command keeps tokens out of arguments and saves
refreshed credentials back through Git. Use it for API requests instead of copying
a token or signing in separately. A permission error does not discard the saved
credential or automatically open another sign-in window.

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
The `nixpkgs-atlas-apps` input holds Forgejo at its deployed 15.0.9 during the
database migration; advance that application pin separately from PostgreSQL.
The `nixpkgs-nook-apps` input holds Home Assistant and Sonarr at their deployed
versions. Advance it separately from infrastructure changes that do not need
application database migrations.

The recipe builds the host closure plus host-specific deploy-rs schema and activation checks before it opens the deployment connection. Nix may still use the remote builders declared by this flake during that build. The recipe then passes `--skip-checks` to deploy-rs because Forge's full-flake check has pre-existing development-shell check failures. Do not use `--skip-checks` without those targeted builds.

Atlas needs one bootstrap from its existing auto-updater after this change reaches `main`. That activation adds `lisa` to Nix's trusted users. Confirm it before the first deploy-rs run:

```sh
ssh atlas 'nix config show trusted-users'
```

Vega and Asterion remain local and manual. On either host, run:

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
