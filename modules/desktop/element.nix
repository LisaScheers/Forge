{
  home.lisa-vega.programs.element-desktop = {
    enable = true;
  };
  # Its module manages web config.json, not the private Electron preferences.
  home.lisa-vega.forge.mutablePreferences = {
    "Library/Application Support/Element/electron-config.json" = {
      settings = {
        warnBeforeExit = true;
        minimizeToTray = true;
        spellCheckerEnabled = true;
        autoHideMenuBar = true;
        disableHardwareAcceleration = false;
        enableContentProtection = false;
        openAtLoginMinimised = true;
        locale = [
          "en"
        ];
      };
    };
  };
}
