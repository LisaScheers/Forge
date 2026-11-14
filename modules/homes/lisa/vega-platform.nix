{
  home.lisa-vega =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      defaultBrowserBundleId = "net.imput.helium";

      appTile = path: {
        tile-data.file-data = {
          _CFURLString = path;
          _CFURLStringType = 15;
        };
        tile-type = "file-tile";
      };
    in
    {
      # Symlinks avoid copying app bundles and the App Management permission loop.
      targets.darwin.copyApps.enable = false;
      targets.darwin.linkApps.enable = true;

      targets.darwin.defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          NSAutomaticCapitalizationEnabled = true;
          NSAutomaticPeriodSubstitutionEnabled = true;
        };
        "com.apple.finder" = {
          FXPreferredViewStyle = "clmv";
          ShowPathbar = true;
        };
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            "25" = {
              enabled = false;
            };
            "18" = {
              enabled = false;
            };
            "26" = {
              enabled = false;
            };
            "19" = {
              enabled = false;
            };
            "79" = {
              enabled = true;
            };
            "64" = {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  32
                  49
                  1048576
                ];
              };
            };
            "20" = {
              enabled = false;
            };
            "80" = {
              enabled = true;
            };
            "21" = {
              enabled = false;
            };
            "81" = {
              enabled = true;
            };
            "176" = {
              enabled = false;
              value = {
                type = "SAE1.0";
              };
            };
            "22" = {
              enabled = false;
            };
            "15" = {
              enabled = false;
            };
            "82" = {
              enabled = true;
            };
            "30" = {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  115
                  1
                  1179648
                ];
              };
            };
            "60" = {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  32
                  49
                  262144
                ];
              };
            };
            "16" = {
              enabled = false;
            };
            "23" = {
              enabled = false;
            };
            "164" = {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  65535
                  65535
                  0
                ];
              };
            };
            "31" = {
              enabled = true;
              value = {
                type = "standard";
                parameters = [
                  115
                  1
                  1179648
                ];
              };
            };
            "61" = {
              value = {
                type = "standard";
                parameters = [
                  32
                  49
                  786432
                ];
              };
              enabled = false;
            };
            "17" = {
              enabled = false;
            };
            "24" = {
              enabled = false;
            };
          };
        };
        "com.apple.AppleMultitouchTrackpad" = {
          Clicking = 0;
          TrackpadThreeFingerDrag = false;
          TrackpadRightClick = true;
          TrackpadTwoFingerDoubleTapGesture = 1;
          TrackpadThreeFingerHorizSwipeGesture = 2;
          TrackpadThreeFingerVertSwipeGesture = 2;
          TrackpadPinch = 1;
          TrackpadRotate = 1;
          TrackpadScroll = true;
        };
        "com.apple.dock" = {
          autohide = true;
          "persistent-apps" = map appTile [
            "file:///System/Applications/Apps.app/"
            "file:///System/Applications/Mail.app/"
            "file:///Applications/Helium.app/"
            "file:///System/Applications/Calendar.app/"
            "file:///Applications/ChatGPT.app/"
            "file:///Applications/Nix%20Apps/Zed%20Nightly.app/"
            "file:///Applications/Nix%20Apps/Ghostty.app/"
            "file:///Applications/Discord.app/"
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
      };

      targets.darwin.currentHostDefaults."com.apple.controlcenter" = {
        BatteryShowPercentage = true;
      };

      home.activation.restartDock = lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
        run /usr/bin/killall Dock || true
      '';

      home.activation.setDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f /Applications/Helium.app \
          || warnEcho "Failed to register Helium with Launch Services"
        run ${pkgs.duti}/bin/duti -s ${defaultBrowserBundleId} http \
          || warnEcho "Failed to set Helium as the HTTP handler"
        # macOS rejects direct HTTPS handler changes with permErr (-54).
      '';
    };
}
