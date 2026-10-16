{
  lib,
  inputs,
  ...
}: {
  options.flake-root = lib.mkOption {
    type = lib.types.path;
    description = ''
      Provides `config.flake-root` with the path to the flake root.
    '';
    default = ../..;
  };

  imports = [
    inputs.flake-file.flakeModules.default
    inputs.flake-file.flakeModules.nix-auto-follow
  ];

  config.flake-file.inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = "github:denful/flake-file";
    import-tree.url = "github:denful/import-tree";
  };

  # A structural refactor must not silently repin transitive inputs when the
  # generated manifest is refreshed.
  config.flake-file.prune-lock.enable = false;
}
