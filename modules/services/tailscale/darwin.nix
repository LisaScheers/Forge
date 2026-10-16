{config, ...}: {
  darwin.base.imports = [config.darwin.networking];
  darwin.networking = {
    services.tailscale = {
      enable = true;
      overrideLocalDns = false;
    };
  };
}
