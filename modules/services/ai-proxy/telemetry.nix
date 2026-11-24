# Usage telemetry from the clients that sign in to their providers directly.
# Claude Code and Codex send OpenTelemetry events, without prompt or response
# text, to a collector on Nook that writes them to ClickHouse beside the
# gateway's captures.
{
  config,
  lib,
  ...
}: let
  inherit (config.flake.lib) nginxPrivateNetworks;
  nook = config.network.nook;
  domain = "otel.local.bylisa.dev";
  endpoint = "https://${domain}";
  # The collector's OTLP/HTTP listener; only nginx reaches it.
  listen = "127.0.0.1:4318";
  # The integration test runs this same configuration, with --set for its ports.
  collectorSettings = {
    receivers.otlp.protocols.http.endpoint = listen;
    processors.batch = {};
    exporters.clickhouse = {
      endpoint = "tcp://127.0.0.1:9000";
      database = "otel";
      username = "ai_otel";
      password = "\${env:AI_OTEL_CLICKHOUSE_PASSWORD}";
      create_schema = true;
    };
    service.pipelines = lib.genAttrs ["logs" "metrics" "traces"] (_: {
      receivers = ["otlp"];
      processors = ["batch"];
      exporters = ["clickhouse"];
    });
  };
in {
  # Collector 0.155.0 vendors cockroachdb/swiss, which does not compile with
  # Nixpkgs' default Go 1.27 (undefined hashFn and fastrand64). Drop this once
  # Nixpkgs builds otelcol-contrib with its default Go.
  overlays.opentelemetry-collector = final: prev: {
    opentelemetry-collector-releases = prev.opentelemetry-collector-releases.override {
      go = final.go_1_26;
      buildGoModule = final.buildGo126Module;
    };
  };

  flake.lib.aiTelemetryCollectorSettings = collectorSettings;

  nixos.base.networking.hosts.${nook.tailscale} = [domain];
  darwin.base.forge.hosts.${nook.tailscale} = [domain];

  home.lisa = {
    programs.claude-code.settings.env = {
      CLAUDE_CODE_ENABLE_TELEMETRY = "1";
      OTEL_METRICS_EXPORTER = "otlp";
      OTEL_LOGS_EXPORTER = "otlp";
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
      OTEL_EXPORTER_OTLP_ENDPOINT = endpoint;
      # Flush every 10 s rather than 60 s, so short sessions keep their last metrics.
      OTEL_METRIC_EXPORT_INTERVAL = "10000";
      # Spans linking each prompt to its API requests and tool runs; they carry
      # timings and token counts, with prompt and tool text redacted.
      CLAUDE_CODE_ENHANCED_TELEMETRY_BETA = "1";
      OTEL_TRACES_EXPORTER = "otlp";
      # Prompt text, tool details and tool output stay out unless these are 1.
      OTEL_LOG_USER_PROMPTS = "0";
      OTEL_LOG_TOOL_DETAILS = "0";
      OTEL_LOG_TOOL_CONTENT = "0";
    };
    programs.codex.settings.otel = {
      # Each host overrides this with its own name, so events can be told apart.
      environment = lib.mkDefault "forge";
      exporter.otlp-http = {
        endpoint = "${endpoint}/v1/logs";
        protocol = "binary";
      };
      trace_exporter = "none";
      # Unset, Codex sends metrics to its vendor's Statsig instead.
      metrics_exporter = "none";
      log_user_prompt = false;
      log_agent_responses = false;
      # Unset, Codex copies the first 2,048 bytes of every tool result into its events.
      tool_result.max_bytes = 0;
    };
  };
  home.lisa-vega.programs.codex.settings.otel.environment = "vega";
  home.lisa-asterion.programs.codex.settings.otel.environment = "asterion";
  home.lisa-nook.programs.codex.settings.otel.environment = "nook";

  nixos.nook = {pkgs, ...}: {
    services.opentelemetry-collector = {
      enable = true;
      package = pkgs.opentelemetry-collector-contrib;
      settings = collectorSettings;
    };
    systemd.services.opentelemetry-collector = {
      requires = ["clickhouse.service"];
      after = ["clickhouse.service"];
      serviceConfig.EnvironmentFile = "/srv/disks/projects/ai-usage-secrets/otel.env";
    };

    security.acme.certs.${domain} = {
      extraLegoFlags = ["--dns.propagation.wait" "30s"];
      group = "nginx";
      reloadServices = ["nginx.service"];
    };
    # Write-only telemetry from LAN and Tailscale clients. Requests are small,
    # so size and rate limits bound what a misbehaving client can store.
    services.nginx.appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=otel:1m rate=20r/s;
    '';
    services.nginx.virtualHosts.${domain} = {
      forceSSL = true;
      useACMEHost = domain;
      extraConfig =
        nginxPrivateNetworks
        + ''
          access_log off;
          client_max_body_size 4m;
          limit_req zone=otel burst=100 nodelay;
        '';
      locations."~ ^/v1/(logs|metrics|traces)$".proxyPass = "http://${listen}";
      locations."/".return = "404";
    };
  };
}
