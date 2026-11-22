{lib, ...}: {
  # Exported from FreeCAD's preferences; the app may rewrite user.cfg.
  home.lisa-vega.forge.mutablePreferences."Library/Preferences/FreeCAD/v1-1/user.cfg" = {
    settings = lib.importJSON ./user.cfg.json;
    format = "freecad";
  };
}
