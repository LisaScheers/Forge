# Forge

## About

This flake manages Nook, Atlas, and Vega. Altair no longer exists and is not a flake output.

## Deployment

Deployments use the locked `deploy-rs` input. Run the server commands from Vega, where the SSH aliases and builders are configured. Every command names one host; there is no fleet-wide deployment recipe.

```sh
just deploy-build nook
just deploy nook dry
just deploy nook test
just deploy nook
```

Use the same commands for Atlas. The Atlas recipe refuses dirty or off-main revisions, aborts when an auto-update or scheduled reboot is active, and pauses `nix-auto-sync-update.timer` while deploy-rs runs. It restarts the timer after a successful deployment or a preflight abort. If deploy-rs itself fails, the timer stays stopped so it cannot retry the same bad `main` revision; the recipe prints the recovery command.

The recipe builds the host closure plus host-specific deploy-rs schema and activation checks before it opens the deployment connection. Nix may still use the remote builders declared by this flake during that build. The recipe then passes `--skip-checks` to deploy-rs because Forge's full-flake check has pre-existing failures in its generated-lock and flake-parts/devenv checks. Do not use `--skip-checks` without those targeted builds.

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

1. This project was built using [tsandrini/flake-parts-builder](https://github.com/tsandrini/flake-parts-builder/)
2. Deployments use [serokell/deploy-rs](https://github.com/serokell/deploy-rs)
