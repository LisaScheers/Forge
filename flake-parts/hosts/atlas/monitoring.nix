{
  config,
  lib,
  pkgs,
  ...
}: let
  instance = "matrix.bylisa.dev";
  otlpEndpoint = "https://grafana.bylisa.dev/otlp";

  alloyAddress = "127.0.0.1";
  alloyPort = 12345;
  cadvisorAddress = "127.0.0.1";
  cadvisorPort = 18080;
  nginxExporterAddress = "127.0.0.1";
  nginxExporterPort = 9113;
  postgresExporterAddress = "127.0.0.1";
  postgresExporterPort = 9187;
  redisExporterAddress = "127.0.0.1";
  redisExporterPort = 9121;
  synapseMetricsAddress = "127.0.0.1";
  synapseMetricsPort = 9002;

  alloyConfig = pkgs.writeText "matrix-alloy-config.alloy" ''
    otelcol.auth.basic "home_server" {
      username = sys.env("OTLP_USERNAME")
      password = sys.env("OTLP_PASSWORD")
    }

    otelcol.exporter.otlphttp "home_server" {
      client {
        endpoint = "${otlpEndpoint}"
        auth     = otelcol.auth.basic.home_server.handler
      }
    }

    otelcol.processor.batch "home_server" {
      output {
        metrics = [otelcol.exporter.otlphttp.home_server.input]
        logs    = [otelcol.exporter.otlphttp.home_server.input]
        traces  = [otelcol.exporter.otlphttp.home_server.input]
      }
    }

    otelcol.receiver.prometheus "local" {
      output {
        metrics = [otelcol.processor.batch.home_server.input]
      }
    }

    prometheus.exporter.unix "host" {
      enable_collectors = ["systemd"]
    }

    discovery.relabel "host" {
      targets = prometheus.exporter.unix.host.targets

      rule {
        target_label = "instance"
        replacement  = "${instance}"
      }

      rule {
        target_label = "job"
        replacement  = "matrix-node"
      }
    }

    prometheus.scrape "host" {
      targets         = discovery.relabel.host.output
      forward_to      = [otelcol.receiver.prometheus.local.receiver]
      scrape_interval = "15s"
    }

    prometheus.scrape "services" {
      targets = [
        {"__address__" = "${alloyAddress}:${toString alloyPort}", "job" = "matrix-alloy", "instance" = "${instance}"},
        {"__address__" = "${cadvisorAddress}:${toString cadvisorPort}", "job" = "matrix-cadvisor", "instance" = "${instance}"},
        {"__address__" = "${nginxExporterAddress}:${toString nginxExporterPort}", "job" = "matrix-nginx", "instance" = "${instance}"},
        {"__address__" = "${postgresExporterAddress}:${toString postgresExporterPort}", "job" = "matrix-postgres", "instance" = "${instance}"},
        {"__address__" = "${redisExporterAddress}:${toString redisExporterPort}", "job" = "matrix-redis", "instance" = "${instance}"},
        {"__address__" = "${synapseMetricsAddress}:${toString synapseMetricsPort}", "job" = "matrix-synapse", "instance" = "${instance}"},
        {"__address__" = "127.0.0.1:9300", "job" = "matrix-authentik", "instance" = "${instance}"},
        {"__address__" = "127.0.0.1:3000", "job" = "forgejo", "instance" = "git.bylisa.dev"},
      ]
      forward_to      = [otelcol.receiver.prometheus.local.receiver]
      scrape_interval = "15s"
    }

    discovery.relabel "journal" {
      targets = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__boot_id"]
        target_label  = "boot_id"
      }

      rule {
        source_labels = ["__journal__transport"]
        target_label  = "transport"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    otelcol.receiver.loki "journal" {
      output {
        logs = [otelcol.processor.batch.home_server.input]
      }
    }

    loki.source.journal "system" {
      max_age       = "24h"
      labels        = {"instance" = "${instance}", "source" = "journal"}
      relabel_rules = discovery.relabel.journal.rules
      forward_to    = [otelcol.receiver.loki.journal.receiver]
    }
  '';
in {
  environment.etc."alloy/config.alloy".source = alloyConfig;

  age.secrets.monitoring-otlp-env = {
    file = ../../agenix/secrets/atlas/monitoring-otlp-env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.alloy = {
    enable = true;
    environmentFile = config.age.secrets.monitoring-otlp-env.path;
    extraFlags = [
      "--server.http.listen-addr=${alloyAddress}:${toString alloyPort}"
      "--disable-reporting"
    ];
  };

  services.cadvisor = {
    enable = true;
    listenAddress = cadvisorAddress;
    port = cadvisorPort;
  };

  services.matrix-synapse.settings = {
    enable_metrics = true;
    listeners = lib.mkAfter [
      {
        port = synapseMetricsPort;
        bind_addresses = [synapseMetricsAddress];
        type = "metrics";
        tls = false;
      }
    ];
  };

  services.nginx.statusPage = true;

  services.prometheus.exporters = {
    nginx = {
      enable = true;
      listenAddress = nginxExporterAddress;
      port = nginxExporterPort;
      scrapeUri = "http://127.0.0.1/nginx_status";
    };

    postgres = {
      enable = true;
      listenAddress = postgresExporterAddress;
      port = postgresExporterPort;
      runAsLocalSuperUser = true;
    };

    redis = {
      enable = true;
      listenAddress = redisExporterAddress;
      port = redisExporterPort;
      extraFlags = ["-redis.addr=redis://127.0.0.1:6379"];
    };
  };

  systemd.services = {
    alloy.restartTriggers = [../../agenix/secrets/atlas/monitoring-otlp-env.age];
    alloy.after = [
      "cadvisor.service"
      "prometheus-nginx-exporter.service"
      "prometheus-postgres-exporter.service"
      "prometheus-redis-exporter.service"
    ];

    prometheus-postgres-exporter = {
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
    };

    prometheus-redis-exporter = {
      after = ["redis-authentik.service"];
      requires = ["redis-authentik.service"];
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };
}
