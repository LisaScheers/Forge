# Shared Nix language configuration

`modules/development/nixd.nix` defines nixd settings for all editors. Forge exports
them as `lib.nixdSettings pkgs`; Zed and Nixvim pass that same value through their
normal LSP settings. Both use the unmodified `pkgs.nixd` from Forge's Nixpkgs pin.
Zed selects nixd for Nix files; Nixvim delegates Nix formatting to nixd.

Home Manager also installs the settings as `~/.config/nixd/config.json`. nixd
does not read that file automatically: another editor can load the JSON and
send its contents for the LSP `nixd` configuration section. No wrapper or
`--config` argument is involved. The checked-in VS Code settings only select
nixd and the alejandra extension; nixd's defaults read Nixpkgs from Forge's
pinned `nix-path`.

The shared settings provide:

- Packages from `import <nixpkgs> { }`.
- Alejandra from an absolute Nix store path, matching `checks.lint`.
- Forge's NixOS, nix-darwin, Home Manager, flake-parts, flake-file, and devenv
  option declarations. The Home Manager selection follows the target platform:
  Vega on Darwin, Asterion on ARM Linux, Nook on x86 Linux.

Option expressions read the host's Forge checkout: `/Users/lisa/Projects/Scheers/forge`
on Darwin and `/etc/nixos/forge` on Linux. They work from other project
directories and follow uncommitted edits to tracked files without a rebuild. Keeping the
repository's store copy out of the editor configuration means edits elsewhere in
Forge leave it, and the host builds that include it, unchanged. Rebuild after
changing the shared settings themselves.

## Nixpkgs lookup

`modules/flake/nix.nix` points `nix.nixPath`, the `nix-path` setting, and the
`nixpkgs` flake registry entry at Forge's locked Nixpkgs input. The declarations
cover NixOS, nix-darwin, and standalone Home Manager. Home Manager replaces the
inherited search path to avoid retaining stale channel entries.

After the separately approved system/Home Manager activation, start a new shell
and restart editors so they receive the new environment. Then:

```sh
nix-instantiate --find-file nixpkgs
nix eval --impure --raw --expr '(import <nixpkgs> { }).lib.version'
```

The resolved path must match Forge's Nixpkgs input. Importing Nix search paths
requires impure evaluation when using `nix eval`.
