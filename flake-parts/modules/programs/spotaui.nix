{inputs, ...}: {
  forge.modules.darwin.spotaui = {
    pkgs,
    config,
    lib,
    ...
  }: let
    cfg = config.programs.spotaui;
  in {
    options.programs.spotaui = {
      enable = lib.mkEnableOption "SpotatUI" // {default = true;};
    };
    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        inputs.spotaui.packages.${pkgs.system}.default
      ];
    };
  };
  forge.modules.nixos.spotaui = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.programs.spotaui;
  in {
    options.programs.spotaui = {
      enable = lib.mkEnableOption "SpotatUI" // {default = true;};
    };
    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        inputs.spotaui.packages.${pkgs.system}.default
      ];
    };
  };
  forge.modules.homeManager.spotaui = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.programs.spotaui;
  in {
    options.programs.spotaui = {
      enable = lib.mkEnableOption "SpotatUI" // {default = true;};
    };
    config = lib.mkIf cfg.enable {
      home.packages = [
        inputs.spotaui.packages.${pkgs.system}.default
      ];
    };
  };
  forge.overlays.spotaui = final: prev: {
    spotaui = inputs.spotaui.packages.${final.system}.default;
  };

  flake-file.inputs = {
    spotaui = {
      url = "github:LargeModGames/spotatui";
    };
  };
}
