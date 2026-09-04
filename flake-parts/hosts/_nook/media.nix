{
  config,
  lib,
  pkgs,
  ...
}: let
  certificateDomain = "media.local.bylisa.dev";
  jellyfinDomain = "jellyfin.local.bylisa.dev";
  prowlarrDomain = "prowlarr.local.bylisa.dev";
  radarrDomain = "radarr.local.bylisa.dev";
  sonarrDomain = "sonarr.local.bylisa.dev";
  transmissionDomain = "transmission.local.bylisa.dev";
  mediaRoot = "/srv/disks/western-digital-hdd/media";
  libraryRoot = "${mediaRoot}/library";
  downloadsRoot = "${mediaRoot}/downloads";
  mediaRoutingMark = "200";
  mediaResolvConf = pkgs.writeText "media-egress-resolv.conf" ''
    nameserver 9.9.9.9
    nameserver 149.112.112.112
    options edns0 single-request-reopen no-aaaa timeout:2 attempts:3
  '';
  mediaDnsMount = "${mediaResolvConf}:/etc/static/resolv.conf";
  arrDotnetEnvironment = [
    "DOTNET_SYSTEM_NET_DISABLEIPV6=1"
    "DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_HTTP2SUPPORT=0"
  ];
  mediaServiceUsers = [
    "radarr"
    "sonarr"
    "prowlarr"
    "transmission"
  ];
  mediaEgressRules = pkgs.writeShellApplication {
    name = "media-egress-routing-rules";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      private_v4=(
        0.0.0.0/8
        10.0.0.0/8
        100.64.0.0/10
        127.0.0.0/8
        169.254.0.0/16
        172.16.0.0/12
        192.168.0.0/16
        224.0.0.0/4
        240.0.0.0/4
      )
      private_v6=(
        ::1/128
        fe80::/10
        fc00::/7
        ff00::/8
      )
      users=(${lib.escapeShellArgs mediaServiceUsers})

      delete_rules_for_uid() {
        local uid="$1"

        while ip -4 rule delete uidrange "$uid-$uid" 2>/dev/null; do :; done
        while ip -6 rule delete uidrange "$uid-$uid" 2>/dev/null; do :; done
      }

      case "''${1:-start}" in
        start)
          for user in "''${users[@]}"; do
            uid="$(id -u "$user")"
            delete_rules_for_uid "$uid"

            priority=19800
            for cidr in "''${private_v4[@]}"; do
              ip -4 rule add priority "$priority" uidrange "$uid-$uid" to "$cidr" table main
              priority=$((priority + 1))
            done
            ip -4 rule add priority 19900 uidrange "$uid-$uid" table media-egress

            priority=19800
            for cidr in "''${private_v6[@]}"; do
              ip -6 rule add priority "$priority" uidrange "$uid-$uid" to "$cidr" table main
              priority=$((priority + 1))
            done
            ip -6 rule add priority 19900 uidrange "$uid-$uid" to 2000::/3 unreachable
          done
          ;;
        stop)
          for user in "''${users[@]}"; do
            delete_rules_for_uid "$(id -u "$user")"
          done
          ;;
        *)
          echo "usage: $0 {start|stop}" >&2
          exit 64
          ;;
      esac
    '';
  };
  mediaServiceUserSet = lib.concatStringsSep ", " mediaServiceUsers;
  proxyErrorPage = import ./_nginx-error-page.nix {inherit pkgs;};
  proxyHost = port:
    lib.mkMerge [
      proxyErrorPage
      {
        forceSSL = true;
        useACMEHost = certificateDomain;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      }
    ];
in {
  hardware.graphics = {
    enable = true;
    extraPackages = [pkgs.mesa];
  };

  security.acme.certs.${certificateDomain} = {
    extraDomainNames = [
      jellyfinDomain
      prowlarrDomain
      radarrDomain
      sonarrDomain
      transmissionDomain
    ];
    extraLegoFlags = [
      "--dns.propagation-wait"
      "30s"
    ];
    group = "nginx";
    reloadServices = ["nginx.service"];
  };

  users.groups.media = {};
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  users.users.prowlarr = {
    isSystemUser = true;
    group = "media";
    home = "${mediaRoot}/prowlarr";
  };

  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 0775 root media -"
    "d ${libraryRoot} 0775 root media -"
    "d ${libraryRoot}/movies 0775 root media -"
    "d ${libraryRoot}/tv 0775 root media -"
    "d ${downloadsRoot} 0775 root media -"
    "d ${downloadsRoot}/complete 0775 transmission media -"
    "d ${downloadsRoot}/complete/radarr 0775 transmission media -"
    "d ${downloadsRoot}/complete/sonarr 0775 transmission media -"
    "d ${downloadsRoot}/incomplete 0775 transmission media -"
    "d ${downloadsRoot}/watch 0775 transmission media -"
    "d ${mediaRoot}/jellyfin 0750 jellyfin media -"
    "d ${mediaRoot}/jellyfin/cache 0750 jellyfin media -"
    "d ${mediaRoot}/jellyfin/config 0750 jellyfin media -"
    "d ${mediaRoot}/jellyfin/data 0750 jellyfin media -"
    "d ${mediaRoot}/jellyfin/log 0750 jellyfin media -"
    "d ${mediaRoot}/prowlarr 0750 prowlarr media -"
    "d ${mediaRoot}/radarr 0750 radarr media -"
    "d ${mediaRoot}/sonarr 0750 sonarr media -"
    "d ${mediaRoot}/transmission 0750 transmission media -"
    "d ${mediaRoot}/transmission/.config 0750 transmission media -"
    "d ${mediaRoot}/transmission/.config/transmission-daemon 0750 transmission media -"
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    group = "media";
    cacheDir = "${mediaRoot}/jellyfin/cache";
    configDir = "${mediaRoot}/jellyfin/config";
    dataDir = "${mediaRoot}/jellyfin/data";
    logDir = "${mediaRoot}/jellyfin/log";
  };

  services.radarr = {
    enable = true;
    openFirewall = false;
    group = "media";
    dataDir = "${mediaRoot}/radarr";
    settings = {
      update.mechanism = "external";
      server = {
        bindaddress = "127.0.0.1";
        port = 7878;
      };
    };
  };

  services.sonarr = {
    enable = true;
    openFirewall = false;
    group = "media";
    dataDir = "${mediaRoot}/sonarr";
    settings = {
      update.mechanism = "external";
      server = {
        bindaddress = "127.0.0.1";
        port = 8989;
      };
    };
  };

  services.prowlarr = {
    enable = true;
    openFirewall = false;
    dataDir = "${mediaRoot}/prowlarr";
    settings = {
      update.mechanism = "external";
      server = {
        bindaddress = "127.0.0.1";
        port = 9696;
      };
    };
  };

  services.transmission = {
    enable = true;
    group = "media";
    home = "${mediaRoot}/transmission";
    openPeerPorts = true;
    openRPCPort = true;
    downloadDirPermissions = "775";
    settings = {
      download-dir = "${downloadsRoot}/complete";
      incomplete-dir = "${downloadsRoot}/incomplete";
      incomplete-dir-enabled = true;
      peer-port = 51413;
      rpc-bind-address = "0.0.0.0";
      rpc-port = 9091;
      rpc-whitelist = "127.0.0.1,192.168.*.*,100.*.*.*";
      rpc-whitelist-enabled = true;
      umask = 2;
      watch-dir = "${downloadsRoot}/watch";
      watch-dir-enabled = true;
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      ${certificateDomain} = proxyHost 8096;
      ${jellyfinDomain} = proxyHost 8096;
      ${prowlarrDomain} = proxyHost 9696;
      ${radarrDomain} = proxyHost 7878;
      ${sonarrDomain} = proxyHost 8989;
      ${transmissionDomain} = proxyHost 9091;
    };
  };

  networking.nftables = {
    # The build sandbox has no media service users. Substitute a known UID only
    # while syntax-checking; the deployed rules resolve the real host users.
    preCheckRuleset = ''
      sed 's/meta skuid { ${mediaServiceUserSet} }/meta skuid root/g' -i ruleset.conf
    '';
    tables.media-egress = {
      family = "inet";
      content = ''
        set local_ipv4 {
          type ipv4_addr
          flags interval
          elements = {
            0.0.0.0/8,
            10.0.0.0/8,
            100.64.0.0/10,
            127.0.0.0/8,
            169.254.0.0/16,
            172.16.0.0/12,
            192.168.0.0/16,
            224.0.0.0/4,
            240.0.0.0/4
          }
        }

        chain mark-media-egress {
          type route hook output priority mangle; policy accept;
          meta skuid { ${mediaServiceUserSet} } ip daddr != @local_ipv4 meta mark set ${mediaRoutingMark}
          meta skuid { ${mediaServiceUserSet} } ip6 daddr 2000::/3 meta mark set ${mediaRoutingMark}
        }
      '';
    };
  };

  systemd.services = {
    media-egress-routing-rules = {
      description = "Policy routing rules for media service VLAN egress";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      before = [
        "radarr.service"
        "sonarr.service"
        "prowlarr.service"
        "transmission.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mediaEgressRules}/bin/media-egress-routing-rules start";
        ExecStop = "${mediaEgressRules}/bin/media-egress-routing-rules stop";
      };
    };
    jellyfin.unitConfig.RequiresMountsFor = mediaRoot;
    radarr = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = mediaRoot;
      serviceConfig = {
        BindReadOnlyPaths = [mediaDnsMount];
        Environment = arrDotnetEnvironment;
        ReadWritePaths = [mediaRoot];
        UMask = lib.mkForce "0002";
      };
    };
    sonarr = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = mediaRoot;
      serviceConfig = {
        BindReadOnlyPaths = [mediaDnsMount];
        Environment = arrDotnetEnvironment;
        ReadWritePaths = [mediaRoot];
        UMask = lib.mkForce "0002";
      };
    };
    prowlarr = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = mediaRoot;
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        ExecStart = lib.mkForce "${config.services.prowlarr.package}/bin/Prowlarr -nobrowser -data=${mediaRoot}/prowlarr";
        BindReadOnlyPaths = [mediaDnsMount];
        Environment = arrDotnetEnvironment;
        Group = "media";
        ReadWritePaths = [mediaRoot];
        StateDirectory = lib.mkForce "";
        UMask = "0002";
        User = "prowlarr";
      };
    };
    transmission = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = mediaRoot;
      serviceConfig = {
        BindReadOnlyPaths = [mediaDnsMount];
        ReadWritePaths = [mediaRoot];
      };
    };
  };
}
