{
  home.lisa-vega.programs.docker-cli = {
    enable = false;
    # Keep the configuration in OrbStack's existing directory.
    configDir = ".docker";
    settings = {
      credsStore = "osxkeychain";
      currentContext = "orbstack";
    };
  };
}
