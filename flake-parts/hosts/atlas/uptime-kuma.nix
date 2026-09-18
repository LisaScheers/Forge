{
  forge.modules.nixos.atlas = {config, ...}: {
    services.uptime-kuma.enable = true;

    services.nginx.virtualHosts."uptime.bylisa.dev" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${config.services.uptime-kuma.settings.HOST}:${config.services.uptime-kuma.settings.PORT}";
        proxyWebsockets = true;
      };
    };
  };
}
