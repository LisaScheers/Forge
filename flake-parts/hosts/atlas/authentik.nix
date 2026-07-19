{
  config,
  pkgs,
  ...
}: let
  authentikEnvironmentFile = config.age.secrets.authentik-env.path;
  authentikLdapEnvironmentFile = config.age.secrets.authentik-ldap-outpost-env.path;
  htmlPlansOAuthEnvironmentFile = config.age.secrets.html-plans-oauth-env.path;
  grafanaBlueprint = pkgs.writeText "authentik-grafana-blueprint.yaml" ''
    version: 1

    metadata:
      name: Grafana OAuth2/OIDC

    entries:
      - model: authentik_providers_oauth2.oauth2provider
        identifiers:
          name: Grafana
        id: grafana-provider
        attrs:
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          client_type: confidential
          grant_types:
            - authorization_code
          client_id: grafana
          client_secret: !Env GRAFANA_CLIENT_SECRET
          redirect_uris:
            - matching_mode: strict
              url: https://grafana.bylisa.dev/login/generic_oauth
            - matching_mode: strict
              url: https://grafana.local.bylisa.dev/login/generic_oauth
          logout_uri: https://grafana.bylisa.dev/logout
          logout_method: frontchannel
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]

      - model: authentik_core.application
        identifiers:
          slug: grafana
        attrs:
          name: Grafana
          provider: !KeyOf grafana-provider
  '';
  htmlPlansBlueprint = pkgs.writeText "authentik-html-plans-blueprint.yaml" ''
    version: 1

    metadata:
      name: HTML Plans
      labels:
        blueprints.goauthentik.io/instantiate: "false"

    entries:
      - model: authentik_providers_proxy.proxyprovider
        identifiers:
          name: HTML Plans
        id: html-plans-proxy-provider
        attrs:
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          external_host: https://plans.bylisa.dev
          mode: forward_single
          intercept_header_auth: true
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: Proxy outpost"]]

      - model: authentik_providers_oauth2.oauth2provider
        identifiers:
          name: HTML Plans API
        id: html-plans-api-provider
        attrs:
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          client_type: confidential
          grant_types:
            - client_credentials
          client_id: html-plans-api
          client_secret: !Env HTML_PLANS_AUTH_CLIENT_SECRET
          access_token_validity: minutes=10
          redirect_uris: []
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]
          jwt_federation_providers:
            - !KeyOf html-plans-proxy-provider

      - model: authentik_core.application
        identifiers:
          slug: html-plans
        attrs:
          name: HTML Plans
          provider: !KeyOf html-plans-proxy-provider
          meta_description: Private, shareable implementation plans
          meta_publisher: Lisa Scheers

      - model: authentik_core.application
        identifiers:
          slug: html-plans-api
        attrs:
          name: HTML Plans API
          provider: !KeyOf html-plans-api-provider
          meta_description: Machine-to-machine access for publishing HTML plans
          meta_hide: true

      - model: authentik_outposts.outpost
        identifiers:
          managed: goauthentik.io/outposts/embedded
        attrs:
          providers:
            - !KeyOf html-plans-proxy-provider
  '';
in {
  services.authentik = {
    enable = true;
    environmentFile = authentikEnvironmentFile;

    settings = {
      email = {
        host = "m.scheers.tech";
        port = 587;
        use_tls = true;
        use_ssl = false;
        from = "auth@scheers.tech";
      };
      disable_startup_analytics = true;
      avatars = "initials";
      blueprints_dir = "/var/lib/authentik/blueprints";
      postgresql.host = "/run/postgresql";
    };

    nginx = {
      enable = true;
      enableACME = true;
      host = "auth.bylisa.dev";
    };
  };

  age.secrets = {
    authentik-env = {
      file = ../../agenix/secrets/atlas/authentik-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    authentik-ldap-outpost-env = {
      file = ../../agenix/secrets/atlas/authentik-ldap-outpost-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    html-plans-oauth-env = {
      file = ../../agenix/secrets/shared/html-plans-oauth-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.authentik-ldap-outpost = {
    image = "ghcr.io/goauthentik/ldap:2025.12.4";
    autoStart = true;
    environment = {
      AUTHENTIK_HOST = "https://auth.bylisa.dev";
      AUTHENTIK_INSECURE = "false";
    };
    environmentFiles = [
      authentikLdapEnvironmentFile
    ];
    ports = [
      "636:6636"
    ];
  };

  systemd.services.authentik-grafana-blueprint = {
    description = "Apply Grafana Authentik OAuth2/OIDC blueprint";
    requiredBy = ["authentik.service"];
    before = ["authentik.service"];
    after = ["authentik-migrate.service"];
    requires = ["authentik-migrate.service"];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      User = "authentik";
      StateDirectory = "authentik";
      WorkingDirectory = "%S/authentik";
      EnvironmentFile = [authentikEnvironmentFile];
      Environment = [
        "AUTHENTIK_CONFIG=/etc/authentik/config.yml"
      ];
      ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${grafanaBlueprint} %S/authentik/blueprints/grafana.yaml";
      ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint grafana.yaml";
    };
  };

  systemd.services.authentik-html-plans-blueprint = {
    description = "Apply HTML Plans Authentik blueprint";
    requiredBy = ["authentik.service"];
    before = ["authentik.service"];
    after = ["authentik-migrate.service"];
    requires = ["authentik-migrate.service"];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      User = "authentik";
      StateDirectory = "authentik";
      WorkingDirectory = "%S/authentik";
      EnvironmentFile = [
        authentikEnvironmentFile
        htmlPlansOAuthEnvironmentFile
      ];
      Environment = [
        "AUTHENTIK_CONFIG=/etc/authentik/config.yml"
      ];
      ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${htmlPlansBlueprint} %S/authentik/blueprints/html-plans.yaml";
      ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint html-plans.yaml";
    };
  };

  systemd.services = {
    authentik.restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    authentik-worker.restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    authentik-grafana-blueprint.restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    authentik-html-plans-blueprint.restartTriggers = [
      ../../agenix/secrets/atlas/authentik-env.age
      ../../agenix/secrets/shared/html-plans-oauth-env.age
    ];
    docker-authentik-ldap-outpost.restartTriggers = [../../agenix/secrets/atlas/authentik-ldap-outpost-env.age];
  };

  networking.firewall.allowedTCPPorts = [636];
}
