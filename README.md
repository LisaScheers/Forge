# Forge

## About

This flake manages Nook, Atlas, and Vega. Altair no longer exists and is not a flake output.

[Asterion](docs/asterion.md) is the experimental Asahi configuration for the
16-inch M3 Pro MacBook Pro, with a dedicated installer image. Installation is
manual; it is not part of the server deployment or automatic update paths.
Encrypted console boot is verified. Native niri remains blocked by M3 graphics
support; the Home Manager desktop configuration is provided for future use.

## Architecture

Forge follows the [dendritic pattern](https://github.com/mightyiam/dendritic),
reviewed against upstream commit `6c76240658cf1c840faad557c0e0726064170a65`.
Every feature `.nix` file below `flake-parts/` is a top-level flake-parts module,
loaded automatically by [`import-tree`](https://github.com/denful/import-tree).
There are no hidden host/home module trees or local lower-level import lists.

`forge.hosts` describes each machine's class, platform, and selected module;
`forge.homes` describes standalone user environments. Features contribute to
class-checked deferred modules in `forge.modules`. For example, every Nook feature
merges into `forge.modules.nixos.nook`, and the four shared shell features merge
into `forge.modules.homeManager.lisa-shell`. Adding a feature to an existing
composition requires no import-list edit. Standalone and embedded homes use the
same composition. `flake.modules` exports those values for external consumers.

Features own their inputs, overlays, and settings. Shared values such as recipient
keys and Nginx error-page settings are top-level options. Selecting a Forge feature
activates it by default; compatibility opt-outs and optional sub-features remain
configurable. Lisa's disabled proxy is an unselected `lisa-proxy` composition.
Upstream NixOS/Home Manager modules retain their own option contracts.

The documented exceptions are package recipes named `*.pkg.nix` and entry points:
`flake.nix`, `outputs.nix`, and `flake-parts/agenix/_secrets.nix` for the agenix CLI.
Package recipes are excluded from automatic loading, as upstream explicitly
permits. The agenix entry point reads the flake's `agenixRules` output. The
`dendritic` check rejects hidden feature files and lower-level module roots.

The earlier HTML migration plan is historical and does not define this architecture.

Installation recipes consume the checked-in hardware features. To replace one,
save the target's `nixos-generate-config --show-hardware-config` output locally,
then run `just hardware-config nook /path/to/hardware-configuration.nix` and review
the result before installation. This wraps the generated expression in a top-level
feature; passing a hardware feature directly to nixos-anywhere's raw configuration
generator would overwrite its module boundary.

## Deployment

Deployments use the locked `deploy-rs` input. Run the server commands from Vega, where the SSH aliases and builders are configured. Every command names one host; there is no fleet-wide deployment recipe.

```sh
just deploy-build nook
just deploy nook dry
just deploy nook test
just deploy nook
```

Use the same commands for Atlas. The Atlas recipe refuses dirty or off-main revisions, aborts when an auto-update or scheduled reboot is active, and pauses `nix-auto-sync-update.timer` while deploy-rs runs. It restarts the timer after a successful deployment or a preflight abort. If deploy-rs itself fails, the timer stays stopped so it cannot retry the same bad `main` revision; the recipe prints the recovery command.

The recipe builds the host closure plus host-specific deploy-rs schema and activation checks before it opens the deployment connection. Nix may still use the remote builders declared by this flake during that build. The recipe then passes `--skip-checks` to deploy-rs because Forge's full-flake check has pre-existing failures in its flake-parts/devenv checks. Do not use `--skip-checks` without those targeted builds.

Atlas needs one bootstrap from its existing auto-updater after this change reaches `main`. That activation adds `lisa` to Nix's trusted users. Confirm it before the first deploy-rs run:

```sh
ssh atlas 'nix config show trusted-users'
```

Vega remains local and manual. Its deploy node points to `localhost` and uses interactive sudo. Bootstrap its SSH configuration once through the existing local activation path, then build and deploy it normally:

```sh
just vega-bootstrap
ssh -o BatchMode=yes localhost true
just deploy-build vega
just deploy vega
```

Do not use deploy-rs dry, test, or boot modes for Vega. The nix-darwin activator in the pinned deploy-rs revision does not implement those modes as real activations.

Keep console access available for the first deploy-rs activation on every host. The generation installed before deploy-rs does not contain its rollback wrapper. Later activations use automatic and connection-confirmed rollback with a 10-minute activation timeout and a 60-second confirmation timeout.

GitHub Actions is deferred. When added, it may deploy Nook and Atlas. Vega stays manual.

## References

1. Module classes use [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
2. Recursive loading uses [denful/import-tree](https://github.com/denful/import-tree)
3. Deployments use [serokell/deploy-rs](https://github.com/serokell/deploy-rs)
