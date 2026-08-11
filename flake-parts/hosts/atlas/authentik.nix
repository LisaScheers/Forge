{
  config,
  pkgs,
  ...
}: let
  authentikEnvironmentFile = config.age.secrets.authentik-env.path;
  authentikLdapEnvironmentFile = config.age.secrets.authentik-ldap-outpost-env.path;
  postplanEnvironmentFile = config.age.secrets.postplan-env.path;
  awsIdentityCenterReady = pkgs.writeShellScript "authentik-aws-identity-center-ready" ''
    [[ -n "''${AWS_IDENTITY_CENTER_ACS_URL:-}" ]]
    [[ -n "''${AWS_IDENTITY_CENTER_AUDIENCE:-}" ]]
  '';
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
  postplanBlueprint = pkgs.writeText "authentik-postplan-blueprint.yaml" ''
    version: 1

    metadata:
      name: PostPlan OAuth2/OIDC

    entries:
      - model: authentik_providers_oauth2.oauth2provider
        identifiers:
          name: PostPlan
        id: postplan-provider
        attrs:
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          client_type: confidential
          grant_types:
            - authorization_code
          client_id: postplan
          client_secret: !Env AUTHENTIK_CLIENT_SECRET
          redirect_uris:
            - matching_mode: strict
              url: https://plans.bylisa.dev/auth/callback
          property_mappings:
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
            - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]

      - model: authentik_core.application
        identifiers:
          slug: postplan
        attrs:
          name: PostPlan
          provider: !KeyOf postplan-provider
  '';
  awsIdentityCenterBlueprint = pkgs.writeText "authentik-aws-identity-center-blueprint.yaml" ''
    version: 1

    metadata:
      name: AWS IAM Identity Center
      labels:
        blueprints.goauthentik.io/instantiate: "false"

    entries:
      - model: authentik_core.group
        id: aws-identity-center-users
        state: created
        identifiers:
          name: AWS IAM Identity Center Users
        attrs:
          is_superuser: false

      - model: authentik_providers_saml.samlprovider
        id: aws-identity-center-provider
        identifiers:
          name: AWS IAM Identity Center
        attrs:
          authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
          invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          acs_url: !Env AWS_IDENTITY_CENTER_ACS_URL
          audience: !Env AWS_IDENTITY_CENTER_AUDIENCE
          sp_binding: post
          name_id_mapping: !Find [authentik_providers_saml.samlpropertymapping, [name, "authentik default SAML Mapping: Email"]]
          default_name_id_policy: urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
          signing_kp: !Find [authentik_crypto.certificatekeypair, [name, "authentik Self-signed Certificate"]]
          sign_assertion: true
          sign_response: false
          property_mappings:
            - !Find [authentik_providers_saml.samlpropertymapping, [name, "authentik default SAML Mapping: Email"]]

      - model: authentik_core.application
        id: aws-identity-center-application
        identifiers:
          slug: aws-iam-identity-center
        attrs:
          name: AWS IAM Identity Center
          provider: !KeyOf aws-identity-center-provider
          meta_description: AWS access through authentik SAML SSO
          meta_publisher: AWS

      - model: authentik_policies.policybinding
        identifiers:
          target: !KeyOf aws-identity-center-application
          group: !KeyOf aws-identity-center-users
          order: 0
        attrs:
          enabled: true
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
      ExecStartPre = [
        "${pkgs.coreutils}/bin/install -D -m 0600 ${grafanaBlueprint} %S/authentik/blueprints/grafana.yaml"
      ];
      ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint grafana.yaml";
    };
    restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
  };

  systemd.services.authentik-postplan-blueprint = {
    description = "Apply PostPlan Authentik OAuth2/OIDC blueprint";
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
      EnvironmentFile = [authentikEnvironmentFile postplanEnvironmentFile];
      Environment = [
        "AUTHENTIK_CONFIG=/etc/authentik/config.yml"
      ];
      ExecStartPre = [
        "${pkgs.coreutils}/bin/install -D -m 0600 ${postplanBlueprint} %S/authentik/blueprints/postplan.yaml"
      ];
      ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint postplan.yaml";
    };
    restartTriggers = [
      ../../agenix/secrets/atlas/authentik-env.age
      ../../agenix/secrets/shared/postplan-env.age
    ];
  };

  # AWS supplies these values only after IAM Identity Center is enabled and its
  # service-provider metadata is downloaded. Until both variables exist in
  # authentik-env.age, ExecCondition skips this blueprint without failing the
  # authentik deployment.
  systemd.services.authentik-aws-identity-center-blueprint = {
    description = "Apply AWS IAM Identity Center Authentik SAML blueprint";
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
      ExecCondition = "${awsIdentityCenterReady}";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/install -D -m 0600 ${awsIdentityCenterBlueprint} %S/authentik/blueprints/aws-iam-identity-center.yaml"
      ];
      ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint aws-iam-identity-center.yaml";
    };
    restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
  };

  systemd.services = {
    authentik.restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    authentik-worker.restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    docker-authentik-ldap-outpost.restartTriggers = [../../agenix/secrets/atlas/authentik-ldap-outpost-env.age];
  };

  networking.firewall.allowedTCPPorts = [636];
}
