let
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
  programs.codex.settings = {
    desktop = {
      conversationDetailMode = "STEPS_COMMANDS";
      sansFontSize = 14;
      codeFontSize = 13;
      "ambient-suggestions-enabled" = false;
      followUpQueueMode = "queue";
      "hotkey-window-projectless-default-enabled" = true;
      "dock-icon-preference" = "codex-system";
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
      "open-in-target-preferences".global = "vscode";
    };

    projects = builtins.listToAttrs (
      map (path: {
        name = path;
        value.trust_level = "trusted";
      })
      trustedProjects
    );
  };
}
