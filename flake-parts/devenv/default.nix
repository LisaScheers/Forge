# --- flake-parts/devenv/default.nix
{
  inputs,
  lib,
  ...
}: {
  imports = with inputs; [devenv.flakeModule];

  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: {
    devenv.shells.dev = import ./_dev.nix {
      inherit pkgs system inputs;
      treefmt-wrapper =
        if (lib.hasAttr "treefmt" config)
        then config.treefmt.build.wrapper
        else null;
    };

    devShells.default = config.devShells.dev;
  };

  flake-file.inputs = {
    devenv.url = "github:cachix/devenv";
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };
}
