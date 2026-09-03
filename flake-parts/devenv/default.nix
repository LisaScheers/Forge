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
    devenv.shells.dev = import ./dev.nix {
      inherit pkgs system inputs;
      treefmt-wrapper =
        if (lib.hasAttr "treefmt" config)
        then config.treefmt.build.wrapper
        else null;
    };

    devShells.default = config.devShells.dev;
  };
}
