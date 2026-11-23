# Forge: rules for coding agents

This flake configures Nook, Atlas, Vega and Asterion. Lisa's global instructions
still apply; this file adds what is specific to this repository. The
[README](README.md) explains the layout, and [docs/agents.md](docs/agents.md)
explains how the agents themselves are configured.

## Boundaries

- Never activate or deploy without Lisa's approval for that action: `just switch`,
  `just deploy`, `darwin-rebuild switch`, `nixos-rebuild switch`, `home-manager
  switch` and deploy-rs. The clients ask before these (`modules/development/agent-policy.nix`).
  Building a host without activating it (`just deploy-build HOST`) is allowed.
- Never decrypt, print or re-encrypt agenix secrets. New secrets go in
  `modules/security/agenix/recipients.nix`, encrypted to Lisa and exactly the
  hosts that read them.
- Nook and Atlas are production: anything that changes them needs Lisa's approval.

## Structure

- Every `.nix` file under `modules/` is a top-level flake-parts module (the
  `dendritic` check). A feature binds itself to a profile such as `nixos.nook` or
  `home.lisa`; do not add host conditionals inside a shared module.
- Inputs are declared next to the feature with `flake-file.inputs`; run
  `just write-flake` after changing one. Never edit `flake.nix` by hand.
- Service source and tests live in `services/<name>/`, workstation tools in
  `tools/<name>/`, package recipes in `packages/<name>/`.

## Checks

Run the narrowest check that proves the change, then `just lint`:

| Change | Check |
| --- | --- |
| Agent clients, MCP, skills, instructions | `nix build .#checks.aarch64-darwin.agent-policy` |
| A home profile | `nix build '.#homeConfigurations."lisa@vega".activationPackage' --no-link` |
| A host | `just deploy-build HOST` (Linux builds use the configured remote builders) |
| A service under `services/` | its `checks.<system>.<name>` from the module that runs it |
| Everything on this system | `just check` |

`just fmt` formats Nix and packages. CI builds every host and check but never
deploys.
