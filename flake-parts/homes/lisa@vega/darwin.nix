{
  config,
  lib,
  pkgs,
  ...
}: let
  defaultBrowserBundleId = "net.imput.helium";

  appTile = path: {
    tile-data.file-data = {
      _CFURLString = path;
      _CFURLStringType = 15;
    };
    tile-type = "file-tile";
  };
in {
  targets.darwin.defaults."com.apple.dock" = {
    autohide = true;
    "persistent-apps" = map appTile [
      "file:///System/Applications/Apps.app/"
      "file:///System/Applications/Mail.app/"
      "file:///Applications/Helium.app/"
      "file:///System/Applications/Calendar.app/"
      "file:///Applications/ChatGPT.app/"
      "file:///Applications/Visual%20Studio%20Code.app/"
      "file:///Applications/Nix%20Apps/Ghostty.app/"
      "file:///Applications/Discord.app/"
      "file:///Applications/Firestorm-Nightlyx64.app/"
      "file:///Applications/Spotify.app/"
      "file:///System/Applications/System%20Settings.app/"
      "file:///Applications/1Password.app/"
    ];
    "show-recents" = false;
    "persistent-others" = [
      {
        tile-data = {
          arrangement = 2;
          displayas = 0;
          file-data = {
            _CFURLString = "file://${config.home.homeDirectory}/Downloads";
            _CFURLStringType = 15;
          };
          showas = 1;
        };
        tile-type = "directory-tile";
      }
    ];
  };

  targets.darwin.currentHostDefaults."com.apple.controlcenter" = {
    BatteryShowPercentage = true;
  };

  home.activation.restartDock = lib.hm.dag.entryAfter ["setDarwinDefaults"] ''
    run /usr/bin/killall Dock || true
  '';

  home.activation.setDefaultBrowser = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -f /Applications/Helium.app
    run ${pkgs.duti}/bin/duti -s ${defaultBrowserBundleId} http
    run ${pkgs.duti}/bin/duti -s ${defaultBrowserBundleId} https
  '';
}
