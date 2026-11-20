{
  config,
  lib,
  ...
}: let
  inherit (config.network) nook;
in {
  # Exported from Firestorm's preferences; the viewer may rewrite these files.
  home.lisa-vega.forge.mutablePreferences = {
    "Library/Application Support/Firestorm/user_settings/settings.xml" = {
      # Firestorm reaches the web and SOCKS5 proxies on Nook's LAN address.
      settings = lib.recursiveUpdate (lib.importJSON ./settings.json) {
        BrowserProxyAddress.Value = nook.lan;
        Socks5ProxyHost.Value = nook.lan;
      };
      format = "llsd";
    };
    "Library/Application Support/Firestorm/user_settings/quick_preferences.xml" = {
      settings = lib.importJSON ./quick-preferences.json;
      format = "xml";
    };
  };
}
