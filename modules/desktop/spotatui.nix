{
  config,
  inputs,
  ...
}: {
  home.lisa-vega.imports = [config.home.spotaui];
  darwin.spotaui = {
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
  nixos.spotaui = {
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
  home.spotaui = {
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
  overlays.spotaui = final: prev: {
    spotaui = inputs.spotaui.packages.${final.system}.default;
  };

  flake-file.inputs = {
    spotaui = {
      url = "github:LargeModGames/spotatui";
    };
  };

  home.lisa-vega.forge.mutablePreferences = {
    ".config/spotatui/config.yml" = {
      settings = {
        behavior = {
          enable_global_song_count = true;
        };
      };
      format = "yaml";
    };
    ".config/spotatui/client.yml" = {
      settings = {
        enable_streaming = true;
        streaming_device_name = "spotatui";
        streaming_bitrate = 320;
        streaming_audio_cache = false;
      };
      format = "yaml";
    };
  };
}
