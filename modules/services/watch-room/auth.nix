{
  nixos.atlas = {
    # Preserve the application host across both nginx hops so the embedded
    # outpost can select the matching forward-auth provider.
    services.nginx.virtualHosts."auth.bylisa.dev".locations."^~ /outpost.goauthentik.io/" = {
      proxyPass = "https://127.0.0.1:9443";
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
    };
    forge.authentik.blueprints.watch-room = {
      description = "Apply watch room Authentik provider and owner policy";
      file = ../../../services/watch-room/authentik.yaml;
      embeddedOutpostProvider = "Watch room host";
    };
  };
}
