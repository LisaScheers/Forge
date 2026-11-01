{
  home.lisa-vega = let
    trustedProjects = [
      "/private/etc/nix-darwin"
      "/Users/lisa/alias-bins"
      "/Users/lisa/Documents/fight chat control"
      "/Users/lisa/Projects/Scheers/html-plans"
      "/Users/lisa/Projects/Scheers/lsl-tester"
      "/Users/lisa/Projects/Scheers/nova-viewer"
      "/Users/lisa/Projects/Scheers/sl-pony-tack"
      "/Users/lisa/Projects/Scheers/sl-remote"
      "/Users/lisa/Projects/Scheers/sl/viewer"
      "/Users/lisa/Projects/Scheers/t3-code-nix"
      "/Users/lisa/Projects/defib/open-field"
      "/Users/lisa/Projects/defib/open-field-scale"
      "/Users/lisa/Projects/public/firestorm"
      "/Users/lisa/Projects/public/nixpgks"
      "/Users/lisa/Projects/public/viewer"
      "/Users/lisa/obsidian/brain"
    ];
  in {
    # Home Manager exposes Codex config, but not desktop keybindings.
    forge.mutablePreferences = {
      ".codex/keybindings.json" = {
        settings = [
          {
            command = "openAvatarOverlay";
            key = null;
          }
        ];
      };
    };

    programs.codex.settings = {
      model = "gpt-6.1-sol";
      model_reasoning_effort = "high";
      approvals_reviewer = "user";
      service_tier = "priority";
      desktop = {
        conversationDetailMode = "STEPS_COMMANDS";
        sansFontSize = 12;
        codeFontSize = 11;
        "ambient-suggestions-enabled" = false;
        followUpQueueMode = "queue";
        "hotkey-window-projectless-default-enabled" = true;
        "dock-icon-preference" = "space-system";
        "show-context-window-usage" = true;
        "open-local-url-in-target-preference" = "external-browser";
        "enabled-reasoning-efforts" = [
          "low"
          "medium"
          "high"
          "xhigh"
          "ultra"
          "max"
        ];
        "show-ultra-in-model-picker-slider" = false;
        keepRemoteControlAwakeWhilePluggedIn = true;
        "open-in-target-preferences".global = "fileManager";
        "toys-confetti-enabled" = true;
        "avatar-overlay-pet-visible" = false;
        pagesFullWidth = true;
        pagesFontSize = 12;
        appearanceDarkCodeThemeId = "catppuccin";
        appearanceDarkChromeTheme = {
          accent = "#f5c2e7";
          accentSource = "custom";
          contrast = 60;
          ink = "#cdd6f4";
          opaqueWindows = false;
          surface = "#1e1e2e";
          fonts.ui = "\"ComicCode Nerd Font\"";
          semanticColors = {
            diffAdded = "#a6e3a1";
            diffRemoved = "#f38ba8";
            skill = "#cba6f7";
          };
        };
      };

      projects = builtins.listToAttrs (
        map (path: {
          name = path;
          value.trust_level = "trusted";
        })
        trustedProjects
      );
    };
  };
}
