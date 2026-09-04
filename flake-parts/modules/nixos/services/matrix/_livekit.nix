{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.matrix;
  keyFile = "/run/livekit.key";
  fqdn = "${cfg.subDomain}.${cfg.rootDomain}";
in {
  services = lib.mkIf (cfg.enable) {
    livekit = {
      enable = true;
      openFirewall = true;
      settings.room.auto_create = false;
      inherit keyFile;
    };
    lk-jwt-service = {
      enable = true;
      # can be on the same virtualHost as synapse
      livekitUrl = "wss://${fqdn}/livekit/sfu";
      inherit keyFile;
    };
    nginx.virtualHosts.${fqdn}.locations = {
      "^~ /livekit/jwt/" = {
        priority = 400;
        proxyPass = "http://[::1]:${toString config.services.lk-jwt-service.port}/";
      };
      "^~ /livekit/sfu/" = {
        extraConfig = ''
          proxy_send_timeout 120;
          proxy_read_timeout 120;
          proxy_buffering off;

          proxy_set_header Accept-Encoding gzip;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
        priority = 400;
        proxyPass = "http://[::1]:${toString config.services.livekit.settings.port}/";
        proxyWebsockets = true;
      };
    };
  };
  # generate the key when needed
  systemd = lib.mkIf (cfg.enable) {
    services.livekit-key = {
      before = ["lk-jwt-service.service" "livekit.service"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [livekit coreutils gawk];
      script = ''
        echo "Key missing, generating key"
        echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" > "${keyFile}"
      '';
      serviceConfig.Type = "oneshot";
      unitConfig.ConditionPathExists = "!${keyFile}";
    };
    # restrict access to livekit room creation to a homeserver
    services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = cfg.rootDomain;
  };
}
