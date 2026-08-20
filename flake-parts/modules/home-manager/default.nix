# --- flake-parts/modules/home-manager/default.nix
{
  lib,
  inputs,
  self,
  ...
}: let
  inherit (inputs.flake-parts.lib) importApply;
  localFlake = self;
in {
  options.flake.homeModules = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };

  config.flake.homeModules = {
    # NOTE Dogfooding your modules with `importApply` will make them more
    # reusable even outside of your flake. For more info see
    # https://flake.parts/dogfood-a-reusable-module#example-with-importapply

    catppuccin = inputs.catppuccin.homeModules.catppuccin;
    t3-code = inputs.t3-code-nix.homeModules.default;
    ai-environment = importApply ./programs/ai-skills {inherit localFlake;};
    xdg-extra = importApply ./services/xdg-extra {inherit localFlake;};

    # programs_myProgram = importApply ./programs/myProgram { inherit localFlake; };
    # services_myService = importApply ./services/myService { inherit localFlake inputs; };
  };
}
