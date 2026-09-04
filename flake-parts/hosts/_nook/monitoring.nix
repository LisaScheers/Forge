{
  config,
  lib,
  pkgs,
  ...
}: let
  grafanaDomain = "grafana.bylisa.dev";
  grafanaLocalDomain = "grafana.local.bylisa.dev";
  authentikDomain = "auth.bylisa.dev";
  authentikGrafanaApplicationSlug = "grafana";
  authentikGrafanaClientId = "grafana";
  storageRoot = "/srv/disks/western-digital-hdd/monitoring";

  lokiAddress = "127.0.0.1";
  lokiPort = 3100;
  homeAssistantAddress = "127.0.0.1";
  homeAssistantPort = 8123;
  nginxExporterAddress = "127.0.0.1";
  nginxExporterPort = 9113;
  unboundExporterAddress = "127.0.0.1";
  unboundExporterPort = 9167;
  squidExporterAddress = "127.0.0.1";
  squidExporterPort = 9301;
  squidAddress = "192.168.111.2";
  squidPort = 3128;
  mimirAddress = "127.0.0.1";
  mimirPort = 9009;
  tempoAddress = "127.0.0.1";
  tempoPort = 3200;
  tempoOtlpGrpcPort = 14317;
  tempoOtlpHttpPort = 14318;
  pyroscopeAddress = "127.0.0.1";
  pyroscopePort = 4040;
  pyroscopeGrpcPort = 9098;
  pyroscopeMemberlistPort = 7947;
  alloyPyroscopePort = 4041;
  alloyAddress = "127.0.0.1";
  alloyPort = 12345;
  alloyOtlpGrpcPort = 4317;
  alloyOtlpHttpPort = 4318;
  mailcowHost = "mail";
  mailcowPublicIpv4 = "188.245.70.181";
  mailcowPublicIpv6 = "2a01:4f8:1c1e:ba3a::1";
  matrixHost = "matrix.bylisa.dev";
  matrixPublicIpv4 = "188.245.245.32";
  mimirUid = "mimir";
  lokiUid = "loki";
  tempoUid = "tempo";
  pyroscopeUid = "pyroscope";
  proxyErrorPage = import ./_nginx-error-page.nix {inherit pkgs;};

  prometheusDatasource = {
    type = "prometheus";
    uid = mimirUid;
  };
  lokiDatasource = {
    type = "loki";
    uid = lokiUid;
  };

  prometheusTarget = refId: expr: legendFormat: {
    datasource = prometheusDatasource;
    inherit expr legendFormat refId;
  };

  lokiTarget = refId: expr: {
    datasource = lokiDatasource;
    inherit expr refId;
    queryType = "range";
  };

  statPanel = id: title: x: y: w: h: targets: unit: {
    inherit id title targets;
    type = "stat";
    datasource = prometheusDatasource;
    gridPos = {inherit x y w h;};
    options = {
      colorMode = "value";
      graphMode = "area";
      justifyMode = "auto";
      orientation = "auto";
      reduceOptions = {
        calcs = ["lastNotNull"];
        fields = "";
        values = false;
      };
      textMode = "auto";
    };
    fieldConfig.defaults = {
      color.mode = "thresholds";
      thresholds = {
        mode = "absolute";
        steps = [
          {
            color = "red";
            value = null;
          }
          {
            color = "green";
            value = 1;
          }
        ];
      };
      unit = unit;
    };
    fieldConfig.overrides = [];
  };

  timeseriesPanel = id: title: x: y: w: h: targets: unit: {
    inherit id title targets;
    type = "timeseries";
    datasource = prometheusDatasource;
    gridPos = {inherit x y w h;};
    fieldConfig.defaults = {
      custom = {
        drawStyle = "line";
        fillOpacity = 8;
        lineInterpolation = "linear";
        lineWidth = 1;
        pointSize = 5;
        showPoints = "never";
        spanNulls = false;
      };
      unit = unit;
    };
    fieldConfig.overrides = [];
    options = {
      legend = {
        calcs = ["lastNotNull"];
        displayMode = "table";
        placement = "bottom";
        showLegend = true;
      };
      tooltip = {
        mode = "multi";
        sort = "none";
      };
    };
  };

  logsPanel = id: title: x: y: w: h: expr: {
    inherit id title;
    type = "logs";
    datasource = lokiDatasource;
    gridPos = {inherit x y w h;};
    targets = [(lokiTarget "A" expr)];
    options = {
      dedupStrategy = "none";
      enableLogDetails = true;
      prettifyLogMessage = false;
      showCommonLabels = false;
      showLabels = false;
      showTime = true;
      sortOrder = "Descending";
    };
  };

  dashboard = uid: title: tags: panels: {
    inherit panels tags title uid;
    annotations.list = [];
    editable = false;
    fiscalYearStartMonth = 0;
    graphTooltip = 0;
    links = [];
    refresh = "30s";
    schemaVersion = 41;
    style = "dark";
    templating.list = [];
    time = {
      from = "now-6h";
      to = "now";
    };
    timepicker = {};
    timezone = "browser";
    version = 1;
  };

  dashboards = {
    "home-server-overview" = dashboard "home-server-overview" "Home Server Overview" ["home-server" "host"] [
      (statPanel 1 "Node up" 0 0 4 4 [(prometheusTarget "A" ''up{job="integrations/node_exporter"}'' "node")] "none")
      (statPanel 2 "Alloy up" 4 0 4 4 [(prometheusTarget "A" ''up{job="alloy"}'' "alloy")] "none")
      (statPanel 3 "Mimir up" 8 0 4 4 [(prometheusTarget "A" ''up{job="mimir"}'' "mimir")] "none")
      (statPanel 4 "Grafana up" 12 0 4 4 [(prometheusTarget "A" ''up{job="grafana"}'' "grafana")] "none")
      (statPanel 10 "Unbound up" 16 0 4 4 [(prometheusTarget "A" ''up{job="unbound"}'' "unbound")] "none")
      (statPanel 11 "Neo4j up" 20 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="neo4j.service",state="active"}'' "neo4j")] "none")
      (statPanel 12 "Squid up" 0 20 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="squid.service",state="active"}'' "squid")] "none")
      (statPanel 13 "Dante up" 4 20 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="dante.service",state="active"}'' "dante")] "none")
      (statPanel 14 "Media services" 8 20 4 4 [(prometheusTarget "A" ''avg(node_systemd_unit_state{name=~"jellyfin.service|prowlarr.service|radarr.service|sonarr.service|transmission.service",state="active"})'' "media")] "none")
      (timeseriesPanel 5 "CPU usage" 0 4 12 8 [(prometheusTarget "A" ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'' "CPU")] "percent")
      (timeseriesPanel 6 "Memory usage" 12 4 12 8 [(prometheusTarget "A" ''100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'' "memory")] "percent")
      (timeseriesPanel 7 "Filesystem usage" 0 12 12 8 [(prometheusTarget "A" ''100 * (1 - node_filesystem_avail_bytes{mountpoint=~"/|/srv/disks/western-digital-hdd",fstype!~"tmpfs|devtmpfs|overlay"} / node_filesystem_size_bytes{mountpoint=~"/|/srv/disks/western-digital-hdd",fstype!~"tmpfs|devtmpfs|overlay"})'' "{{mountpoint}}")] "percent")
      (timeseriesPanel 8 "Load average" 12 12 12 8 [(prometheusTarget "A" ''node_load1'' "1m") (prometheusTarget "B" ''node_load5'' "5m") (prometheusTarget "C" ''node_load15'' "15m")] "none")
      (logsPanel 9 "System logs" 0 24 24 8 ''{unit=~"alloy.service|dante.service|grafana.service|jellyfin.service|loki.service|mimir.service|neo4j.service|nginx.service|podman-home-assistant.service|prometheus-nginx-exporter.service|prometheus-squid-exporter.service|prometheus-unbound-exporter.service|prowlarr.service|pyroscope.service|radarr.service|sonarr.service|squid.service|tempo.service|transmission.service|unbound.service"}'')
    ];

    "observability-stack" = dashboard "observability-stack" "Observability Stack" ["grafana" "lgtm"] [
      (timeseriesPanel 1 "Stack target health" 0 0 24 8 [(prometheusTarget "A" ''up{job=~"grafana|loki|mimir|tempo|pyroscope|alloy"}'' "{{job}}") (prometheusTarget "B" ''node_systemd_unit_state{name="neo4j.service",state="active"}'' "neo4j")] "none")
      (timeseriesPanel 2 "Alloy remote write rate" 0 8 12 8 [(prometheusTarget "A" ''sum(rate(prometheus_remote_storage_samples_total[5m]))'' "samples/s")] "ops")
      (timeseriesPanel 3 "Alloy pending samples" 12 8 12 8 [(prometheusTarget "A" ''sum(prometheus_remote_storage_samples_pending)'' "pending")] "short")
      (timeseriesPanel 4 "Loki ingest requests" 0 16 12 8 [(prometheusTarget "A" ''sum(rate(loki_request_duration_seconds_count[5m])) by (route)'' "{{route}}")] "rps")
      (timeseriesPanel 5 "Mimir request rate" 12 16 12 8 [(prometheusTarget "A" ''sum(rate(cortex_request_duration_seconds_count[5m])) by (route)'' "{{route}}")] "rps")
      (timeseriesPanel 6 "Neo4j unit state" 0 24 12 8 [(prometheusTarget "A" ''node_systemd_unit_state{name="neo4j.service",state="active"}'' "active") (prometheusTarget "B" ''node_systemd_unit_state{name="neo4j.service",state="failed"}'' "failed")] "none")
      (logsPanel 7 "Observability service logs" 12 24 12 8 ''{unit=~"alloy.service|grafana.service|loki.service|mimir.service|neo4j.service|pyroscope.service|tempo.service"}'')
    ];

    "matrix-remote" = dashboard "matrix-remote" "Matrix Remote Server" ["matrix" "remote" "host"] [
      (statPanel 1 "Node up" 0 0 4 4 [(prometheusTarget "A" ''up{job="matrix-node", instance="${matrixHost}"}'' "node")] "none")
      (statPanel 2 "Alloy up" 4 0 4 4 [(prometheusTarget "A" ''up{job="matrix-alloy", instance="${matrixHost}"}'' "alloy")] "none")
      (statPanel 3 "Failed services" 8 0 4 4 [(prometheusTarget "A" ''sum(node_systemd_unit_state{instance="${matrixHost}", state="failed", name=~".+\\.service"}) or vector(0)'' "failed")] "short")
      (statPanel 4 "Active services" 12 0 4 4 [(prometheusTarget "A" ''sum(node_systemd_unit_state{instance="${matrixHost}", state="active", name=~".+\\.service"})'' "active")] "short")
      (statPanel 5 "Synapse metrics" 16 0 4 4 [(prometheusTarget "A" ''up{job="matrix-synapse", instance="${matrixHost}"}'' "synapse")] "none")
      (statPanel 6 "Container metrics" 20 0 4 4 [(prometheusTarget "A" ''up{job="matrix-cadvisor", instance="${matrixHost}"}'' "cadvisor")] "none")
      (timeseriesPanel 7 "CPU usage" 0 4 12 8 [(prometheusTarget "A" ''100 - (avg(rate(node_cpu_seconds_total{job="matrix-node", instance="${matrixHost}", mode="idle"}[5m])) * 100)'' "CPU")] "percent")
      (timeseriesPanel 8 "Memory usage" 12 4 12 8 [(prometheusTarget "A" ''100 * (1 - node_memory_MemAvailable_bytes{job="matrix-node", instance="${matrixHost}"} / node_memory_MemTotal_bytes{job="matrix-node", instance="${matrixHost}"})'' "memory")] "percent")
      (timeseriesPanel 9 "Filesystem usage" 0 12 12 8 [(prometheusTarget "A" ''100 * (1 - node_filesystem_avail_bytes{job="matrix-node", instance="${matrixHost}", mountpoint=~"/|/nix|/var", fstype!~"tmpfs|devtmpfs|overlay"} / node_filesystem_size_bytes{job="matrix-node", instance="${matrixHost}", mountpoint=~"/|/nix|/var", fstype!~"tmpfs|devtmpfs|overlay"})'' "{{mountpoint}}")] "percent")
      (timeseriesPanel 10 "Load average" 12 12 12 8 [(prometheusTarget "A" ''node_load1{job="matrix-node", instance="${matrixHost}"}'' "1m") (prometheusTarget "B" ''node_load5{job="matrix-node", instance="${matrixHost}"}'' "5m") (prometheusTarget "C" ''node_load15{job="matrix-node", instance="${matrixHost}"}'' "15m")] "none")
      (timeseriesPanel 11 "Key service state" 0 20 24 8 [(prometheusTarget "A" ''node_systemd_unit_state{instance="${matrixHost}", state="active", name=~"authentik.service|authentik-worker.service|bluesky-pds.service|cadvisor.service|docker.service|matrix-synapse.service|nginx.service|postgresql.service|prometheus-nginx-exporter.service|prometheus-postgres-exporter.service|prometheus-redis-exporter.service|redis-authentik.service|shop-empty-track.service|sshd.service|tailscaled.service|atm10-8-0.service"}'' "{{name}}")] "none")
      (timeseriesPanel 12 "Scrape health" 0 28 12 8 [(prometheusTarget "A" ''up{instance="${matrixHost}", job=~"matrix-.+"}'' "{{job}}")] "none")
      (timeseriesPanel 13 "Container CPU" 12 28 12 8 [(prometheusTarget "A" ''sum by (name) (rate(container_cpu_usage_seconds_total{job="matrix-cadvisor", instance="${matrixHost}", name!=""}[5m]))'' "{{name}}")] "cores")
      (logsPanel 14 "Remote service logs" 0 36 24 8 ''{instance="${matrixHost}", source="journal"}'')
    ];

    "nginx" = dashboard "nginx" "Nginx" ["nginx" "proxy"] [
      (statPanel 1 "Nginx up" 0 0 6 4 [(prometheusTarget "A" ''nginx_up'' "nginx")] "none")
      (timeseriesPanel 2 "Requests" 6 0 18 8 [(prometheusTarget "A" ''rate(nginx_http_requests_total[5m])'' "requests/s")] "rps")
      (timeseriesPanel 3 "Connections" 0 8 12 8 [(prometheusTarget "A" ''nginx_connections_active'' "active") (prometheusTarget "B" ''nginx_connections_reading'' "reading") (prometheusTarget "C" ''nginx_connections_writing'' "writing") (prometheusTarget "D" ''nginx_connections_waiting'' "waiting")] "short")
      (timeseriesPanel 4 "Accepted and handled connections" 12 8 12 8 [(prometheusTarget "A" ''rate(nginx_connections_accepted[5m])'' "accepted/s") (prometheusTarget "B" ''rate(nginx_connections_handled[5m])'' "handled/s")] "cps")
      (logsPanel 5 "Nginx logs" 0 16 24 8 ''{unit="nginx.service"}'')
    ];

    "dns" = dashboard "dns" "DNS" ["dns" "unbound"] [
      (statPanel 1 "Unbound up" 0 0 6 4 [(prometheusTarget "A" ''up{job="unbound"}'' "unbound")] "none")
      (statPanel 2 "Queries/s" 6 0 6 4 [(prometheusTarget "A" ''sum(rate(unbound_queries_total{job="unbound"}[5m]))'' "queries")] "qps")
      (statPanel 3 "Cache hit ratio" 12 0 6 4 [(prometheusTarget "A" ''100 * sum(rate(unbound_cache_hits_total{job="unbound"}[5m])) / (sum(rate(unbound_cache_hits_total{job="unbound"}[5m])) + sum(rate(unbound_cache_misses_total{job="unbound"}[5m])))'' "hit ratio")] "percent")
      (statPanel 4 "Request queue" 18 0 6 4 [(prometheusTarget "A" ''sum(unbound_request_list_current_all{job="unbound"})'' "queue")] "short")
      (timeseriesPanel 5 "Query rate" 0 4 12 8 [(prometheusTarget "A" ''sum(rate(unbound_queries_total{job="unbound"}[5m]))'' "queries/s")] "qps")
      (timeseriesPanel 6 "Cache" 12 4 12 8 [(prometheusTarget "A" ''sum(rate(unbound_cache_hits_total{job="unbound"}[5m]))'' "hits/s") (prometheusTarget "B" ''sum(rate(unbound_cache_misses_total{job="unbound"}[5m]))'' "misses/s")] "ops")
      (timeseriesPanel 7 "Response codes" 0 12 12 8 [(prometheusTarget "A" ''sum by (rcode) (rate(unbound_answer_rcodes_total{job="unbound"}[5m]))'' "{{rcode}}")] "qps")
      (timeseriesPanel 8 "Query types" 12 12 12 8 [(prometheusTarget "A" ''sum by (type) (rate(unbound_query_types_total{job="unbound"}[5m]))'' "{{type}}")] "qps")
      (timeseriesPanel 9 "P95 response time" 0 20 12 8 [(prometheusTarget "A" ''histogram_quantile(0.95, sum(rate(unbound_response_time_seconds_bucket{job="unbound"}[5m])) by (le))'' "p95")] "s")
      (logsPanel 10 "Unbound logs" 12 20 12 8 ''{unit=~"unbound.service|prometheus-unbound-exporter.service"}'')
    ];

    "second-life-proxy-cache" = dashboard "second-life-proxy-cache" "Second Life Proxy Cache" ["second-life" "squid" "dante"] [
      (statPanel 1 "Squid exporter up" 0 0 6 4 [(prometheusTarget "A" ''up{job="squid"}'' "exporter")] "none")
      (statPanel 2 "Squid unit up" 6 0 6 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="squid.service",state="active"}'' "squid")] "none")
      (statPanel 3 "Dante unit up" 12 0 6 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="dante.service",state="active"}'' "dante")] "none")
      (statPanel 4 "Cache hit ratio" 18 0 6 4 [(prometheusTarget "A" ''squid_info_Hits_as_pct_of_all_requests_5min'' "hits")] "percent")
      (timeseriesPanel 5 "HTTP requests" 0 4 12 8 [(prometheusTarget "A" ''rate(squid_client_http_requests_total[5m])'' "requests") (prometheusTarget "B" ''rate(squid_client_http_hits_total[5m])'' "hits") (prometheusTarget "C" ''rate(squid_client_http_errors_total[5m])'' "errors")] "rps")
      (timeseriesPanel 6 "Bandwidth" 12 4 12 8 [(prometheusTarget "A" ''rate(squid_client_http_kbytes_in_kbytes_total[5m]) * 1024'' "in") (prometheusTarget "B" ''rate(squid_client_http_kbytes_out_kbytes_total[5m]) * 1024'' "out") (prometheusTarget "C" ''rate(squid_client_http_hit_kbytes_out_bytes_total[5m])'' "hit out")] "Bps")
      (timeseriesPanel 7 "Cache storage" 0 12 12 8 [(prometheusTarget "A" ''squid_info_Storage_Swap_size * 1024'' "disk") (prometheusTarget "B" ''squid_info_Storage_Mem_size * 1024'' "memory")] "bytes")
      (timeseriesPanel 8 "Service times p50" 12 12 12 8 [(prometheusTarget "A" ''squid_HTTP_Requests_All_50'' "http") (prometheusTarget "B" ''squid_Cache_Hits_50'' "hits") (prometheusTarget "C" ''squid_Cache_Misses_50'' "misses") (prometheusTarget "D" ''squid_DNS_Lookups_50'' "dns")] "s")
      (timeseriesPanel 9 "Proxy unit state" 0 20 24 8 [(prometheusTarget "A" ''node_systemd_unit_state{name=~"squid.service|dante.service|prometheus-squid-exporter.service",state=~"active|failed"}'' "{{name}} {{state}}")] "none")
      (logsPanel 10 "Proxy logs" 0 28 24 8 ''{unit=~"squid.service|dante.service|prometheus-squid-exporter.service"}'')
    ];

    "home-assistant" = dashboard "home-assistant" "Home Assistant" ["home-assistant" "iot"] [
      (statPanel 1 "Home Assistant up" 0 0 6 4 [(prometheusTarget "A" ''up{job="home-assistant"}'' "home-assistant")] "none")
      (timeseriesPanel 2 "Process memory" 6 0 9 8 [(prometheusTarget "A" ''process_resident_memory_bytes{job="home-assistant"}'' "RSS")] "bytes")
      (timeseriesPanel 3 "Process CPU" 15 0 9 8 [(prometheusTarget "A" ''rate(process_cpu_seconds_total{job="home-assistant"}[5m])'' "CPU seconds/s")] "cores")
      (timeseriesPanel 4 "Python GC collections" 0 8 12 8 [(prometheusTarget "A" ''sum by (generation) (rate(python_gc_collections_total{job="home-assistant"}[5m]))'' "gen {{generation}}")] "ops")
      (timeseriesPanel 5 "Scrape health" 12 8 12 8 [(prometheusTarget "A" ''scrape_duration_seconds{job="home-assistant"}'' "duration") (prometheusTarget "B" ''scrape_samples_scraped{job="home-assistant"}'' "samples")] "short")
      (logsPanel 6 "Home Assistant logs" 0 16 24 8 ''{unit="podman-home-assistant.service"}'')
    ];

    "mailcow" = dashboard "mailcow" "Mailcow" ["mailcow" "mail"] [
      (statPanel 1 "Mailcow exporter up" 0 0 6 4 [(prometheusTarget "A" ''up{job="mailcow-exporter", instance="${mailcowHost}"}'' "exporter")] "none")
      (statPanel 2 "Mailcow node up" 6 0 6 4 [(prometheusTarget "A" ''up{job="mailcow-node", instance="${mailcowHost}"}'' "node")] "none")
      (statPanel 3 "Container metrics up" 12 0 6 4 [(prometheusTarget "A" ''up{job="mailcow-cadvisor", instance="${mailcowHost}"}'' "cadvisor")] "none")
      (statPanel 4 "Active domains" 18 0 6 4 [(prometheusTarget "A" ''sum(mailcow_domain_active{instance="${mailcowHost}"})'' "domains")] "short")
      (timeseriesPanel 5 "Host CPU usage" 0 4 12 8 [(prometheusTarget "A" ''100 - (avg(rate(node_cpu_seconds_total{job="mailcow-node", instance="${mailcowHost}", mode="idle"}[5m])) * 100)'' "CPU")] "percent")
      (timeseriesPanel 6 "Host memory usage" 12 4 12 8 [(prometheusTarget "A" ''100 * (1 - node_memory_MemAvailable_bytes{job="mailcow-node", instance="${mailcowHost}"} / node_memory_MemTotal_bytes{job="mailcow-node", instance="${mailcowHost}"})'' "memory")] "percent")
      (timeseriesPanel 7 "Container CPU" 0 12 12 8 [(prometheusTarget "A" ''sum by (name) (rate(container_cpu_usage_seconds_total{job="mailcow-cadvisor", instance="${mailcowHost}", name=~"mailcowdockerized-.+"}[5m]))'' "{{name}}")] "cores")
      (timeseriesPanel 8 "Container memory" 12 12 12 8 [(prometheusTarget "A" ''container_memory_working_set_bytes{job="mailcow-cadvisor", instance="${mailcowHost}", name=~"mailcowdockerized-.+"}'' "{{name}}")] "bytes")
      (timeseriesPanel 9 "Exporter provider health" 0 20 12 8 [(prometheusTarget "A" ''mailcow_exporter_success{instance="${mailcowHost}"}'' "{{provider}}")] "none")
      (timeseriesPanel 10 "Rspamd actions" 12 20 12 8 [(prometheusTarget "A" ''sum by (action) (rate(mailcow_rspamd_action{instance="${mailcowHost}"}[5m]))'' "{{action}}")] "ops")
      (logsPanel 11 "Mailcow container logs" 0 28 12 8 ''{instance="${mailcowHost}", source="docker"}'')
      (logsPanel 12 "Mail server journal" 12 28 12 8 ''{instance="${mailcowHost}", source="journal"}'')
    ];

    "media" = dashboard "media" "Media" ["media" "jellyfin" "servarr" "transmission"] [
      (statPanel 1 "Jellyfin up" 0 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="jellyfin.service",state="active"}'' "jellyfin")] "none")
      (statPanel 2 "Radarr up" 4 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="radarr.service",state="active"}'' "radarr")] "none")
      (statPanel 3 "Sonarr up" 8 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="sonarr.service",state="active"}'' "sonarr")] "none")
      (statPanel 4 "Prowlarr up" 12 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="prowlarr.service",state="active"}'' "prowlarr")] "none")
      (statPanel 5 "Transmission up" 16 0 4 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="transmission.service",state="active"}'' "transmission")] "none")
      (statPanel 6 "VLAN 200 link" 20 0 4 4 [(prometheusTarget "A" ''node_network_up{device="enp7s0.200"}'' "enp7s0.200")] "none")
      (timeseriesPanel 7 "Unit state" 0 4 12 8 [(prometheusTarget "A" ''node_systemd_unit_state{name=~"jellyfin.service|prowlarr.service|radarr.service|sonarr.service|transmission.service",state=~"active|failed"}'' "{{name}} {{state}}")] "none")
      (timeseriesPanel 8 "VLAN 200 traffic" 12 4 12 8 [(prometheusTarget "A" ''rate(node_network_receive_bytes_total{device="enp7s0.200"}[5m])'' "receive") (prometheusTarget "B" ''rate(node_network_transmit_bytes_total{device="enp7s0.200"}[5m])'' "transmit")] "Bps")
      (timeseriesPanel 9 "Media storage" 0 12 12 8 [(prometheusTarget "A" ''100 * (1 - node_filesystem_avail_bytes{mountpoint="/srv/disks/western-digital-hdd",fstype!~"tmpfs|devtmpfs|overlay"} / node_filesystem_size_bytes{mountpoint="/srv/disks/western-digital-hdd",fstype!~"tmpfs|devtmpfs|overlay"})'' "western-digital-hdd")] "percent")
      (logsPanel 10 "Media logs" 12 12 12 8 ''{unit=~"jellyfin.service|prowlarr.service|radarr.service|sonarr.service|transmission.service"}'')
    ];

    "neo4j" = dashboard "neo4j" "Neo4j" ["database" "neo4j"] [
      (statPanel 1 "Neo4j up" 0 0 6 4 [(prometheusTarget "A" ''node_systemd_unit_state{name="neo4j.service",state="active"}'' "neo4j")] "none")
      (timeseriesPanel 2 "Unit state" 6 0 18 8 [(prometheusTarget "A" ''node_systemd_unit_state{name="neo4j.service",state="active"}'' "active") (prometheusTarget "B" ''node_systemd_unit_state{name="neo4j.service",state="failed"}'' "failed")] "none")
      (logsPanel 4 "Neo4j logs" 0 8 24 8 ''{unit="neo4j.service"}'')
    ];
  };

  dashboardPath = pkgs.linkFarm "grafana-dashboards" (
    lib.mapAttrsToList (name: dashboardJson: {
      name = "${name}.json";
      path = pkgs.writeText "${name}.json" (builtins.toJSON dashboardJson);
    })
    dashboards
  );

  alloyConfig = pkgs.writeText "config.alloy" ''
    prometheus.remote_write "mimir" {
      endpoint {
        url = "http://${mimirAddress}:${toString mimirPort}/api/v1/push"
      }
    }

    prometheus.exporter.unix "home_server" {
      enable_collectors = ["systemd"]
    }

    discovery.relabel "home_server" {
      targets = prometheus.exporter.unix.home_server.targets

      rule {
        target_label = "instance"
        replacement  = constants.hostname
      }

      rule {
        target_label = "job"
        replacement  = "integrations/node_exporter"
      }
    }

    prometheus.scrape "home_server" {
      targets         = discovery.relabel.home_server.output
      forward_to      = [prometheus.remote_write.mimir.receiver]
      scrape_interval = "15s"
    }

    prometheus.scrape "grafana_stack" {
      targets = [
        {"__address__" = "127.0.0.1:3000",  "job" = "grafana", "instance" = constants.hostname},
        {"__address__" = "${lokiAddress}:${toString lokiPort}",  "job" = "loki",    "instance" = constants.hostname},
        {"__address__" = "${mimirAddress}:${toString mimirPort}", "job" = "mimir",   "instance" = constants.hostname},
        {"__address__" = "${tempoAddress}:${toString tempoPort}", "job" = "tempo",   "instance" = constants.hostname},
        {"__address__" = "${pyroscopeAddress}:${toString pyroscopePort}", "job" = "pyroscope", "instance" = constants.hostname},
        {"__address__" = "${alloyAddress}:${toString alloyPort}", "job" = "alloy",   "instance" = constants.hostname},
      ]
      forward_to      = [prometheus.remote_write.mimir.receiver]
      scrape_interval = "15s"
    }

    prometheus.scrape "home_assistant" {
      targets = [
        {"__address__" = "${homeAssistantAddress}:${toString homeAssistantPort}", "job" = "home-assistant", "instance" = constants.hostname},
      ]
      forward_to      = [prometheus.remote_write.mimir.receiver]
      metrics_path    = "/api/prometheus"
      scrape_interval = "60s"
    }

    prometheus.scrape "nginx" {
      targets = [
        {"__address__" = "${nginxExporterAddress}:${toString nginxExporterPort}", "job" = "nginx", "instance" = constants.hostname},
      ]
      forward_to      = [prometheus.remote_write.mimir.receiver]
      scrape_interval = "15s"
    }

    prometheus.scrape "unbound" {
      targets = [
        {"__address__" = "${unboundExporterAddress}:${toString unboundExporterPort}", "job" = "unbound", "instance" = constants.hostname},
      ]
      forward_to      = [prometheus.remote_write.mimir.receiver]
      scrape_interval = "15s"
    }

    prometheus.scrape "squid" {
      targets = [
        {"__address__" = "${squidExporterAddress}:${toString squidExporterPort}", "job" = "squid", "instance" = constants.hostname},
      ]
      forward_to      = [prometheus.remote_write.mimir.receiver]
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

    loki.write "local" {
      endpoint {
        url = "http://${lokiAddress}:${toString lokiPort}/loki/api/v1/push"
      }
    }

    loki.source.journal "system" {
      max_age       = "24h"
      relabel_rules = discovery.relabel.journal.rules
      forward_to    = [loki.write.local.receiver]
    }

    otelcol.receiver.otlp "local" {
      grpc {
        endpoint = "${alloyAddress}:${toString alloyOtlpGrpcPort}"
      }

      http {
        endpoint = "${alloyAddress}:${toString alloyOtlpHttpPort}"
      }

      output {
        metrics = [otelcol.processor.batch.local.input]
        logs    = [otelcol.processor.batch.local.input]
        traces  = [otelcol.processor.batch.local.input]
      }
    }

    otelcol.processor.batch "local" {
      output {
        metrics = [otelcol.exporter.prometheus.otlp_metrics.input]
        logs    = [otelcol.processor.attributes.loki_labels.input]
        traces  = [otelcol.exporter.otlp.tempo.input]
      }
    }

    otelcol.processor.attributes "loki_labels" {
      action {
        key    = "loki.attribute.labels"
        action = "insert"
        value  = "unit, level, instance, source, job, transport"
      }

      output {
        logs = [otelcol.exporter.loki.otlp_logs.input]
      }
    }

    otelcol.exporter.prometheus "otlp_metrics" {
      forward_to = [prometheus.remote_write.mimir.receiver]
    }

    otelcol.exporter.loki "otlp_logs" {
      forward_to = [loki.write.local.receiver]
    }

    otelcol.exporter.otlp "tempo" {
      client {
        endpoint = "${tempoAddress}:${toString tempoOtlpGrpcPort}"

        tls {
          insecure = true
        }
      }
    }

    pyroscope.write "local" {
      endpoint {
        url = "http://${pyroscopeAddress}:${toString pyroscopePort}"
      }
    }

    pyroscope.receive_http "local" {
      http {
        listen_address = "127.0.0.1"
        listen_port    = ${toString alloyPyroscopePort}
      }

      forward_to = [pyroscope.write.local.receiver]
    }
  '';
in {
  environment.etc."alloy/config.alloy".source = alloyConfig;

  age.secrets = {
    monitoring-otlp-htpasswd = {
      file = ../../agenix/secrets/nook/monitoring-otlp-htpasswd.age;
      owner = "nginx";
      group = "nginx";
      mode = "0440";
    };
    grafana-authentik-client-secret = {
      file = ../../agenix/secrets/nook/grafana-authentik-client-secret.age;
      owner = "grafana";
      group = "grafana";
      mode = "0440";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${storageRoot} 0755 root root -"
    "d ${storageRoot}/grafana 0750 grafana grafana -"
    "d ${storageRoot}/loki 0750 loki loki -"
    "d ${storageRoot}/mimir 0750 mimir mimir -"
    "d ${storageRoot}/tempo 0750 tempo tempo -"
    "d ${storageRoot}/pyroscope 0750 pyroscope pyroscope -"
  ];

  users = {
    groups = {
      mimir = {};
      pyroscope = {};
      tempo = {};
    };
    users = {
      mimir = {
        description = "Mimir service user";
        group = "mimir";
        home = "${storageRoot}/mimir";
        isSystemUser = true;
      };
      pyroscope = {
        description = "Pyroscope service user";
        group = "pyroscope";
        home = "${storageRoot}/pyroscope";
        isSystemUser = true;
      };
      tempo = {
        description = "Tempo service user";
        group = "tempo";
        home = "${storageRoot}/tempo";
        isSystemUser = true;
      };
    };
  };

  services.grafana = {
    enable = true;
    dataDir = "${storageRoot}/grafana";
    settings = {
      analytics.reporting_enabled = false;
      log.mode = "console";
      metrics.enabled = true;
      auth.signout_redirect_url = "https://${authentikDomain}/application/o/${authentikGrafanaApplicationSlug}/end-session/";
      "auth.generic_oauth" = {
        enabled = true;
        name = "authentik";
        allow_sign_up = true;
        client_id = authentikGrafanaClientId;
        client_secret = "$__file{${config.age.secrets.grafana-authentik-client-secret.path}}";
        scopes = "openid email profile";
        auth_url = "https://${authentikDomain}/application/o/authorize/";
        token_url = "https://${authentikDomain}/application/o/token/";
        api_url = "https://${authentikDomain}/application/o/userinfo/";
        use_pkce = true;
        role_attribute_path = "contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'";
      };
      security = {
        admin_user = "admin";
        secret_key = "$__file{${storageRoot}/grafana/secret_key}";
      };
      server = {
        domain = grafanaDomain;
        http_addr = "127.0.0.1";
        http_port = 3000;
        root_url = "https://${grafanaDomain}/";
      };
    };
    provision = {
      enable = true;
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "home-server";
            type = "file";
            disableDeletion = false;
            editable = false;
            updateIntervalSeconds = 30;
            options = {
              path = dashboardPath;
              foldersFromFilesStructure = false;
            };
          }
        ];
      };
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        deleteDatasources = [
          {
            name = "Loki";
            orgId = 1;
          }
          {
            name = "Mimir";
            orgId = 1;
          }
          {
            name = "Tempo";
            orgId = 1;
          }
          {
            name = "Pyroscope";
            orgId = 1;
          }
        ];
        datasources = [
          {
            name = "Loki";
            uid = lokiUid;
            type = "loki";
            access = "proxy";
            url = "http://${lokiAddress}:${toString lokiPort}";
            jsonData.maxLines = 1000;
          }
          {
            name = "Mimir";
            uid = mimirUid;
            type = "prometheus";
            access = "proxy";
            url = "http://${mimirAddress}:${toString mimirPort}/prometheus";
            isDefault = true;
            jsonData = {
              httpMethod = "POST";
            };
          }
          {
            name = "Pyroscope";
            uid = pyroscopeUid;
            type = "grafana-pyroscope-datasource";
            access = "proxy";
            url = "http://${pyroscopeAddress}:${toString pyroscopePort}";
            jsonData.minStep = "15s";
          }
          {
            name = "Tempo";
            uid = tempoUid;
            type = "tempo";
            access = "proxy";
            url = "http://${tempoAddress}:${toString tempoPort}";
            jsonData = {
              nodeGraph.enabled = true;
              serviceMap.datasourceUid = mimirUid;
              tracesToLogsV2 = {
                datasourceUid = lokiUid;
                filterByTraceID = true;
                filterBySpanID = false;
                spanStartTimeShift = "-5m";
                spanEndTimeShift = "5m";
                tags = [
                  {
                    key = "service.name";
                    value = "service";
                  }
                  {
                    key = "host.name";
                    value = "instance";
                  }
                ];
              };
              tracesToMetrics = {
                datasourceUid = mimirUid;
                spanStartTimeShift = "-5m";
                spanEndTimeShift = "5m";
                tags = [
                  {
                    key = "service.name";
                    value = "service";
                  }
                  {
                    key = "host.name";
                    value = "instance";
                  }
                ];
                queries = [
                  {
                    name = "Request rate";
                    query = "sum(rate(traces_spanmetrics_calls_total{$${__tags}}[5m]))";
                  }
                  {
                    name = "Latency p95";
                    query = "histogram_quantile(0.95, sum(rate(traces_spanmetrics_latency_bucket{$${__tags}}[5m])) by (le))";
                  }
                ];
              };
              tracesToProfiles = {
                datasourceUid = pyroscopeUid;
                profileTypeId = "process_cpu:cpu:nanoseconds:cpu:nanoseconds";
                tags = [
                  {
                    key = "service.name";
                    value = "service_name";
                  }
                ];
              };
            };
          }
        ];
      };
    };
  };

  services.loki = {
    enable = true;
    dataDir = "${storageRoot}/loki";
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_address = lokiAddress;
        http_listen_port = lokiPort;
        grpc_listen_address = lokiAddress;
        grpc_listen_port = 9096;
      };
      common = {
        instance_addr = lokiAddress;
        path_prefix = "${storageRoot}/loki";
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
        storage.filesystem = {
          chunks_directory = "${storageRoot}/loki/chunks";
          rules_directory = "${storageRoot}/loki/rules";
        };
      };
      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      compactor = {
        working_directory = "${storageRoot}/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };
      limits_config = {
        retention_period = "30d";
        allow_structured_metadata = true;
      };
    };
  };

  services.mimir = {
    enable = true;
    extraFlags = ["-target=all"];
    configuration = {
      multitenancy_enabled = false;
      server = {
        http_listen_address = mimirAddress;
        http_listen_port = mimirPort;
        grpc_listen_address = "0.0.0.0";
        grpc_listen_port = 9095;
        log_level = "warn";
      };
      blocks_storage = {
        backend = "filesystem";
        bucket_store.sync_dir = "${storageRoot}/mimir/tsdb-sync";
        filesystem.dir = "${storageRoot}/mimir/data/tsdb";
        tsdb.dir = "${storageRoot}/mimir/tsdb";
      };
      compactor = {
        data_dir = "${storageRoot}/mimir/compactor";
        sharding_ring.kvstore.store = "memberlist";
      };
      limits.max_label_names_per_series = 60;
      distributor.ring = {
        instance_addr = mimirAddress;
        kvstore.store = "memberlist";
      };
      ingester.ring = {
        instance_addr = mimirAddress;
        kvstore.store = "memberlist";
        replication_factor = 1;
      };
      memberlist = {
        bind_addr = [mimirAddress];
        bind_port = 7946;
        advertise_addr = mimirAddress;
        advertise_port = 7946;
      };
      ruler_storage = {
        backend = "filesystem";
        filesystem.dir = "${storageRoot}/mimir/rules";
      };
      store_gateway.sharding_ring.replication_factor = 1;
      usage_stats.enabled = false;
    };
  };

  services.tempo = {
    enable = true;
    extraFlags = ["-target=all"];
    settings = {
      auth_enabled = false;
      server = {
        http_listen_address = tempoAddress;
        http_listen_port = tempoPort;
        grpc_listen_address = tempoAddress;
        grpc_listen_port = 9097;
      };
      distributor.receivers.otlp.protocols = {
        grpc.endpoint = "${tempoAddress}:${toString tempoOtlpGrpcPort}";
        http.endpoint = "${tempoAddress}:${toString tempoOtlpHttpPort}";
      };
      storage.trace = {
        backend = "local";
        local.path = "${storageRoot}/tempo/traces";
        wal.path = "${storageRoot}/tempo/wal";
      };
    };
  };

  services.pyroscope = {
    enable = true;
    extraFlags = ["-target=all"];
    settings = {
      analytics.reporting_enabled = false;
      server = {
        http_listen_address = "0.0.0.0";
        http_listen_port = pyroscopePort;
        grpc_listen_address = "0.0.0.0";
        grpc_listen_port = pyroscopeGrpcPort;
      };
      memberlist = {
        bind_addr = [pyroscopeAddress];
        bind_port = pyroscopeMemberlistPort;
        advertise_addr = pyroscopeAddress;
        advertise_port = pyroscopeMemberlistPort;
      };
      storage = {
        backend = "filesystem";
        filesystem.dir = "${storageRoot}/pyroscope/data";
      };
    };
  };

  services.alloy = {
    enable = true;
    extraFlags = [
      "--server.http.listen-addr=${alloyAddress}:${toString alloyPort}"
      "--disable-reporting"
    ];
  };

  services.nginx.statusPage = true;

  services.prometheus.exporters.nginx = {
    enable = true;
    listenAddress = nginxExporterAddress;
    port = nginxExporterPort;
    scrapeUri = "http://127.0.0.1/nginx_status";
  };

  systemd.services.prometheus-squid-exporter = {
    description = "Prometheus exporter for Squid caching proxy";
    wantedBy = ["multi-user.target"];
    after = ["squid.service"];
    requires = ["squid.service"];
    serviceConfig = {
      User = "squid";
      Group = "squid";
      ExecStart = "${pkgs.prometheus-squid-exporter}/bin/squid-exporter -listen ${squidExporterAddress}:${toString squidExporterPort} -squid-hostname ${squidAddress} -squid-port ${toString squidPort} -squid-pidfile /run/squid.pid";
      Restart = "always";
      RestartSec = "5s";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  services.nginx.virtualHosts.${grafanaDomain} = lib.mkMerge [
    proxyErrorPage
    {
      serverAliases = [grafanaLocalDomain];
      forceSSL = true;
      useACMEHost = grafanaDomain;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
      locations."/otlp/" = {
        proxyPass = "http://${alloyAddress}:${toString alloyOtlpHttpPort}/";
        extraConfig = ''
          allow ${mailcowPublicIpv4};
          allow ${mailcowPublicIpv6};
          allow ${matrixPublicIpv4};
          deny all;

          auth_basic "OTLP";
          auth_basic_user_file ${config.age.secrets.monitoring-otlp-htpasswd.path};

          client_max_body_size 25m;
          proxy_http_version 1.1;
        '';
      };
    }
  ];

  systemd.services = {
    nginx.reloadTriggers = [../../agenix/secrets/nook/monitoring-otlp-htpasswd.age];

    alloy = {
      after = [
        "loki.service"
        "mimir.service"
        "pyroscope.service"
        "tempo.service"
      ];
      wants = [
        "loki.service"
        "mimir.service"
        "pyroscope.service"
        "tempo.service"
      ];
      unitConfig.RequiresMountsFor = storageRoot;
    };

    grafana = {
      restartTriggers = [../../agenix/secrets/nook/grafana-authentik-client-secret.age];
      after = [
        "loki.service"
        "mimir.service"
        "pyroscope.service"
        "tempo.service"
      ];
      wants = [
        "loki.service"
        "mimir.service"
        "pyroscope.service"
        "tempo.service"
      ];
      unitConfig.RequiresMountsFor = storageRoot;
      preStart = lib.mkBefore ''
        if [ ! -s ${storageRoot}/grafana/secret_key ]; then
          umask 077
          ${pkgs.openssl}/bin/openssl rand -base64 32 > ${storageRoot}/grafana/secret_key
        fi
      '';
    };

    loki.unitConfig.RequiresMountsFor = storageRoot;
    mimir = {
      unitConfig.RequiresMountsFor = storageRoot;
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "mimir";
        Group = "mimir";
        WorkingDirectory = lib.mkForce "${storageRoot}/mimir";
      };
    };
    pyroscope = {
      unitConfig.RequiresMountsFor = storageRoot;
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "pyroscope";
        Group = "pyroscope";
        WorkingDirectory = lib.mkForce "${storageRoot}/pyroscope";
      };
    };
    tempo = {
      unitConfig.RequiresMountsFor = storageRoot;
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "tempo";
        Group = "tempo";
        WorkingDirectory = lib.mkForce "${storageRoot}/tempo";
      };
    };
  };
}
