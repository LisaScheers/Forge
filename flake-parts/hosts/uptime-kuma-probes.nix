{lib, ...}: let
  # Private services report outward; no extra listening ports are needed.
  mkProbes = host: {config, pkgs, ...}: let
    secret = config.age.secrets.uptime-kuma-probes.path;
    report = pkgs.writeShellApplication {
      name = "uptime-kuma-report";
      runtimeInputs = [pkgs.curl pkgs.jq];
      text = ''
        token=$(jq -er --arg key "$1" '.[$key] | select(type == "string" and length > 0)' ${lib.escapeShellArg secret})
        # Keep the push token out of command arguments and journal messages.
        printf 'url = "https://uptime.bylisa.dev/api/push/%s"\n' "$token" |
          curl --config - --silent --fail --max-time 10 --get \
            --data-urlencode "status=''${2:-up}" \
            --data-urlencode "msg=''${3:-Completed successfully}" \
          | jq -e '.ok == true' >/dev/null
      '';
    };
    httpProbe = key: url: {
      inherit key;
      command = "${pkgs.curl}/bin/curl --fail --silent --max-time 10 ${lib.escapeShellArg url}";
    };
    probes =
      if host == "atlas"
      then [
        {
          key = "postgresql-query";
          command = "${pkgs.util-linux}/bin/runuser -u postgres -- ${config.services.postgresql.package}/bin/psql -X --no-password --dbname=postgres --set=ON_ERROR_STOP=1 --command='SELECT 1'";
        }
      ]
      else [
        (httpProbe "loki" "http://127.0.0.1:3100/ready")
        (httpProbe "mimir" "http://127.0.0.1:9009/ready")
        (httpProbe "tempo" "http://127.0.0.1:3200/ready")
        (httpProbe "sonarr" "http://127.0.0.1:8989/ping")
        (httpProbe "radarr" "http://127.0.0.1:7878/ping")
        (httpProbe "prowlarr" "http://127.0.0.1:9696/ping")
        {
          key = "squid";
          command = "${pkgs.netcat-openbsd}/bin/nc -z -w 5 192.168.111.2 3128";
        }
        {
          key = "dante";
          command = "${pkgs.netcat-openbsd}/bin/nc -z -w 5 192.168.111.2 1080";
        }
      ];
    probeScript = pkgs.writeShellScript "uptime-kuma-probes" (lib.concatMapStringsSep "\n" (probe: ''
      if ${probe.command} >/dev/null 2>&1; then
        ${lib.getExe report} ${lib.escapeShellArg probe.key} up "Local check passed" || true
      else
        ${lib.getExe report} ${lib.escapeShellArg probe.key} down "Local check failed" || true
      fi
    '') probes);
  in {
    age.secrets.uptime-kuma-probes = {
      file = ../agenix/secrets/${host}/uptime-kuma-probes.age;
      mode = "0400";
    };

    systemd.services.uptime-kuma-probes = {
      description = "Report private service health to Uptime Kuma";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = probeScript;
        TimeoutStartSec = 180;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
    systemd.timers.uptime-kuma-probes = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitInactiveSec = "60s";
        AccuracySec = "5s";
      };
    };

    # ExecStartPost runs only after successful oneshot completion. Reporting
    # failure must not turn a successful update or backup into a failed job.
    systemd.services.nix-auto-sync-update.serviceConfig.ExecStartPost = [
      "-${lib.getExe report} auto-update"
    ];
    systemd.services.postgresqlBackup-forgejo = lib.mkIf (host == "atlas") {
      serviceConfig.ExecStartPost = [
        "-+${lib.getExe report} postgresql-backup"
      ];
    };
  };
in {
  forge.modules.nixos.atlas = mkProbes "atlas";
  forge.modules.nixos.nook = mkProbes "nook";
}
