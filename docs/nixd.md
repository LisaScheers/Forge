# Shared Nix language configuration

`packages/nixd/settings.nix` defines nixd settings for all editors. Forge exports
them as `lib.nixdSettings pkgs`; Zed and Nixvim pass that same value through their
normal LSP settings. Both use the unmodified `pkgs.nixd` from Forge's Nixpkgs pin.
Zed selects nixd for Nix files; Nixvim delegates Nix formatting to nixd.

Home Manager also installs the settings as `~/.config/nixd/config.json`. nixd
does not read that file automatically: another editor can load the JSON and
send its contents for the LSP `nixd` configuration section. No wrapper or
`--config` argument is involved.

The shared settings provide:

- Packages from `import <nixpkgs> { }`.
- Nixfmt from an absolute Nix store path.
- Forge's NixOS, nix-darwin, Home Manager, flake-parts, flake-file, and devenv
  option declarations. The Home Manager selection follows the target platform:
  Vega on Darwin, Asterion on ARM Linux, Nook on x86 Linux.

Option expressions refer to the pinned Forge source used to build the editor
configuration. They work from other project directories. Rebuild after changing
the shared settings or Forge option declarations.

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
