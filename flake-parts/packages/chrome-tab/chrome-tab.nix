{
  forge.overlays.chrome-tab = final: _prev: {
    chrome-tab = final.callPackage ./chrome-tab.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {
    packages.chrome-tab = pkgs.chrome-tab;
    checks.chrome-tab = pkgs.chrome-tab;
  };

  forge.modules.homeManager.chrome-tab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.forge.chrome-tab;
    manifestDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support/Google/Chrome/NativeMessagingHosts"
      else ".config/google-chrome/NativeMessagingHosts";
  in {
    options.forge.chrome-tab = {
      enable = lib.mkEnableOption "the Chrome tab JavaScript bridge";
      extensionId = lib.mkOption {
        type = lib.types.strMatching "[a-p]{32}";
        description = "ID shown in chrome://extensions for the unpacked Forge Tab Bridge extension.";
      };
    };
    config = lib.mkIf cfg.enable {
      home.packages = [pkgs.chrome-tab];
      home.file = {
        ".local/share/chrome-tab/extension".source = "${pkgs.chrome-tab}/share/chrome-tab/extension";
        "${manifestDirectory}/dev.bylisa.chrome_tab.json".text = builtins.toJSON {
          name = "dev.bylisa.chrome_tab";
          description = "Forge Tab Bridge";
          path = "${pkgs.chrome-tab}/bin/chrome-tab-native-host";
          type = "stdio";
          allowed_origins = ["chrome-extension://${cfg.extensionId}/"];
        };
      };
    };
  };
}
