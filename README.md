# Forge

## About

This flake manages Nook, Atlas, Vega, and Asterion. Altair no longer exists and
is not a flake output.

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
Asterion's `home.lisa-asterion` profile imports `home.lisa` and adds its own
desktop settings.

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
| `modules/security/` | Agenix, SSH, GnuPG, 1Password |
| `modules/hardware/` | Host hardware, disk support, Apple Silicon installers |
| `packages/` | Raw package recipes and patches, one `packages/<name>/package.nix` entry point each (larger recipes keep helpers beside it); outside automatic loading |

Each host's `default.nix` constructs its NixOS or Darwin output and visibly
selects hardware and Home Manager profiles. Home files construct standalone
outputs using the same home profiles and the shared per-system package set.
There is no host registry or automatic home registration. For example, Nook's
host module binds `home-manager.users.lisa = config.home.lisa-nook`. Each
deployable host also sets `deploy.hosts.<host>` (SSH user and options) in its
host module.

Adding settings to an existing profile requires no file import-list edit.
Distinct reusable profiles are selected explicitly by name. Selecting a feature
enables it by default; existing opt-outs remain available. `home.lisa-proxy` is
an opt-in profile that runs the CLIProxy gateway locally with OpenRouter instead
of using Nook's; no home imports it today, and `checks.lisa-proxy-profile` keeps
it building.
`flake.modules` publishes the named profiles for external consumers.

`flake-file` generates `flake.nix` from feature-owned input declarations.
Regenerate it with `nix run .#write-flake`. The root entry point imports
`modules/` directly. `modules/security/agenix/_secrets.nix` is the standalone
agenix CLI entry point and reads the flake's `agenixRules` output. The underscore
keeps it out of automatic loading. The `dendritic` and `profiles` checks enforce
top-level feature boundaries and module-class safety.

CI targets are declared beside their host, home, or installer output. The CI
module maps those declarations to native runners without evaluating host builds.
A target lists the flake checks that share its closure, such as a host's
toplevel and deploy-rs checks, and its job builds them together; evaluation
fails if a listed check does not exist. Every other check, plus the dev shell,
builds in one `ciChecks.<system>` job per system, and the NixOS VM tests run in
`ciVmTests.x86_64-linux` on the KVM-capable runner. Reproduce them locally with:

```sh
nix build .#ciChecks.aarch64-darwin   # or x86_64-linux / aarch64-linux
nix build .#ciVmTests.x86_64-linux    # needs a builder with kvm and nixos-test
```

`checks.lint` runs alejandra, deadnix and statix (configured in `statix.toml`)
over `modules/` and `packages/`, shellcheck over the repository's shell scripts,
ruff (`ruff.toml`) over its Python and actionlint over the workflows; the
vendored AI skills are excluded.
`nix fmt -- modules packages` formats the Nix.
The dev shell's pre-commit hooks run alejandra on the same paths, nil,
editorconfig-checker and write-flake. `checks.script-tests` runs the Python tests in
`tests/` against the repository scripts, Justfile and helpers they exercise.

Tests sit beside what they cover, and each runs from a flake check: service
suites in `services/<name>/test_*.py`, host helper tests in `scripts/test_*.py`,
tool suites in `tools/<name>/tests/` (run by the package build), fixtures beside
their module under `modules/`, and repository-script tests in `tests/`.

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

Deployments use the locked `deploy-rs` input. Run the server commands from Vega,
where the SSH aliases and builders are configured. Every command names one host;
there is no fleet-wide deployment recipe.

```sh
just deploy-build nook
just deploy nook dry
just deploy nook test
just deploy nook
```

Use the same commands for Atlas. The Atlas recipe refuses dirty or off-main
revisions, aborts when an auto-update or scheduled reboot is active, and pauses
`nix-auto-sync-update.timer` while deploy-rs runs. It restarts the timer after a
successful deployment or a preflight abort. If deploy-rs itself fails, the timer
stays stopped so it cannot retry the same bad `main` revision; the recipe prints
the recovery command. After a kernel change the updater arms a reboot up to 12
hours later, which blocks deploys until then. To deploy sooner, reboot Atlas or
cancel the pending reboot with `ssh atlas sudo systemctl stop
nix-auto-sync-update-reboot.timer` and deploy before the next updater run, which
re-arms it if the activated kernel, initrd or modules still differ from the
booted generation.

systemd loads the Atlas updater's `/run/agenix/auto-sync-update-env`
(`EnvironmentFile=`), so it holds plain `KEY=value` lines and never runs as
shell code: `AUTO_SYNC_SMTP_URL`, `AUTO_SYNC_SMTP_USERNAME`,
`AUTO_SYNC_SMTP_PASSWORD`, `AUTO_SYNC_SMTP_FROM`, `AUTO_SYNC_SMTP_TO` and
`AUTO_SYNC_SMTP_REQUIRE_TLS` for failure mail, and `AUTO_SYNC_GIT_TOKEN`,
`AUTO_SYNC_GIT_USERNAME`, `AUTO_SYNC_GIT_AUTH_HEADER` or
`AUTO_SYNC_GIT_REPOSITORY_URL` for Git access. Write bare values: no quotes, no
`export`, no `$` expansion. systemd skips lines that are not assignments, and
when the file exists but provides no SMTP URL, any run that needs to send mail
fails visibly (and a failed rebuild keeps its own exit status). The updater only
fast-forwards to `origin/main`: if the Atlas checkout has local commits, every
run fails and mails until the checkout is reset to `origin/main`. The journal
has the same reason even if mail fails. Keep the commits on a branch before
resetting:

```sh
ssh atlas sudo journalctl -u nix-auto-sync-update -n 50
# Stop if this lists uncommitted changes; they need handling first.
ssh atlas sudo git -c safe.directory=/etc/nix-darwin -C /etc/nix-darwin status --short
# The reset runs only if the backup branch was created.
ssh atlas 'git() { sudo git -c safe.directory=/etc/nix-darwin -C /etc/nix-darwin "$@"; }
  git branch "atlas-local-$(date +%Y%m%d-%H%M%S)" && git reset --hard origin/main'
```

For an approved database maintenance window, `just deploy-maintenance` applies
Atlas while leaving its updater timer stopped. The root-owned marker
`/var/lib/postgresql/.forge-maintenance` also prevents updater runs across
reboots. Keep the marker and timer hold until migration and recovery checks pass;
then remove the marker and restart `nix-auto-sync-update.timer` explicitly.
Atlas's PostgreSQL major and data directory are pinned in
`modules/services/postgresql/atlas.nix`. Its scheduled `pg_dumpall` backup covers
cluster roles and every database except `matrix-synapse`, `mautrix-discord` and
`pluralmatrix`, which are intentionally unbacked
([Matrix after SEC-Hive](docs/sec-hive-matrix.md)). The existing Uptime Kuma probe
reports completion.
Atlas uses PostgreSQL 18 at `/var/lib/postgresql/18`. Startup requires its
`PG_VERSION` and `.forge-upgrade-complete` marker; create the marker only after a
successful `pg_upgrade` or a verified full restore. Keep the PostgreSQL 16
directory and its system generation for recovery. Returning to it after new
writes requires reconciling those writes or restoring a current backup.
The `nixpkgs-atlas-apps` and `nixpkgs-nook-apps` inputs track Nixpkgs master
for Forgejo, Home Assistant and Sonarr. Their migration holds were removed after
Lisa confirmed migration and recovery checks were complete on 8 November 2026.
Their lock entries still allow application updates separately from infrastructure.
`nixpkgs-atlas-apps` pins Forgejo on Atlas; `nixpkgs-nook-apps` pins Home
Assistant and Sonarr on Nook together, so holding it holds both. The daily lock
workflow advances every input. To hold one, list the other inputs in the
`inputs` setting of `.github/workflows/update-flake-lock.yml`, then advance the
held input later with `nix flake update <input>`.

A deployable host sets `deploy.hosts.<host>` in its host module (its SSH user
and options). Its platform comes from the host's own configuration and selects
the deploy-rs activation, the `deploy-*-<host>` checks and the `deploySystems`
output the recipe reads. The recipe builds the host closure plus host-specific
deploy-rs schema and activation checks before it opens the deployment
connection. Nix may still use the remote builders declared by this flake during
that build. The recipe then passes `--skip-checks` to deploy-rs, which would
otherwise run the whole flake check; CI already builds every flake check. Do not
use `--skip-checks` without those targeted builds.

deploy-rs connects to Atlas as `lisa`, which `modules/hosts/atlas/system.nix`
makes a trusted Nix user. On a freshly installed Atlas, let its auto-updater
apply `main` once, then confirm before the first deploy-rs run:

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

### Rotating the Nook builder key

Vega reaches Nook's `nix-remote-builder` account with
`secrets/vega/home-server-builder-ssh-key.age`, encrypted for Lisa and Vega only.
Nook authorizes exactly one public key, in `modules/hosts/nook/users.nix`, so a
one-sided switch stops Vega's remote builds. After replacing both halves, build
both closures while the old key still works, switch them in one window, and
confirm the connection:

```sh
just deploy-build nook
just deploy-build vega
just deploy nook
just switch                     # on Vega; opens Apple Terminal
```

Wait until that Terminal window prints `Vega switched successfully.`, then
confirm Vega's new key reaches Nook:

```sh
sudo ssh nook-builder true      # uses /etc/nix/nook-builder
```

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

Do not use deploy-rs dry, test, or boot modes for Vega. The nix-darwin activator
in the pinned deploy-rs revision does not implement those modes as real
activations.

Keep console access available for the first deploy-rs activation on every host.
The generation installed before deploy-rs does not contain its rollback wrapper.
Later activations use automatic and connection-confirmed rollback with a
10-minute activation timeout and a 60-second confirmation timeout.

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

The build matrix comes from the `ciMatrix` output (see Architecture): each
NixOS, nix-darwin and standalone Home Manager configuration, both Asterion
installers, the per-system check jobs and the VM tests, each on a native Linux or
macOS runner. These are full builds, with lock-file changes disabled. CI does not
activate configurations or deploy hosts.

## Further documentation

| Guide | Covers |
| --- | --- |
| [Asterion](docs/asterion.md), [live installer](docs/asterion-live.md) | The Asahi MacBook Pro install, desktop and RAM-booted installer |
| [Aurora Viewer](docs/aurora-viewer.md) | Vega's source-built Second Life viewer and its Metal port |
| [AI gateway](docs/ai-usage.md) | The shared CLIProxy gateway and token capture |
| [Cognee](docs/cognee.md) | Cognee on Nook and its MCP endpoint |
| [Home dashboard](docs/home-dashboard.md), [home media](docs/home-media.md) | Nook's dashboard and media access |
| [Minecraft](docs/minecraft.md) | The Nook worlds and Atlas proxy |
| [Gotify](docs/gotify.md), [Uptime Kuma](docs/uptime-kuma.md) | Notifications and monitoring |
| [Certificate trust](docs/certificate-trust.md) | The eMudhra root mitigation |
| [nixd](docs/nixd.md), [Nixvim](docs/nixvim.md) | Editor and language-server setup |
| [REA](docs/rea.md) | Reverse-engineering tooling |
| [Matrix after SEC-Hive](docs/sec-hive-matrix.md) | What Atlas keeps after the SEC-Hive removal, and the check for it |
| [Package audit](docs/package-audit.md) | Dated record of pin and patch decisions |

## References

1. Module classes use [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
2. Recursive loading uses [denful/import-tree](https://github.com/denful/import-tree)
3. Deployments use [serokell/deploy-rs](https://github.com/serokell/deploy-rs)
