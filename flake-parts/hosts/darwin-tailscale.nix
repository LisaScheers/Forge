{...}: {
  forge.modules.darwin.networking = {
    services.tailscale = {
      enable = true;
      overrideLocalDns = false;
    };
  };
}
