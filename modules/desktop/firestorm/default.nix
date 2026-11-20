{lib, ...}: {
  # Exported from Firestorm's preferences; the viewer may rewrite these files.
  home.lisa-vega.forge.mutablePreferences = {
    "Library/Application Support/Firestorm/user_settings/settings.xml" = {
      settings = lib.importJSON ./settings.json;
      format = "llsd";
    };
    "Library/Application Support/Firestorm/user_settings/quick_preferences.xml" = {
      settings = lib.importJSON ./quick-preferences.json;
      format = "xml";
    };
  };
}
