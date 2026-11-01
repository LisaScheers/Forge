{
  home.lisa-vega.programs.vscode = {
    enable = false;
    profiles.default = {
      mutableUserSettings = true;
      userSettings = {
        "editor.accessibilitySupport" = "off";
        "editor.formatOnSave" = true;
        "files.autoSave" = "onFocusChange";
        "github.copilot.enable" = {
          nix = true;
        };
      };
    };
  };
}
