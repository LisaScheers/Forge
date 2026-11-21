{
  nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    authentikEnvironmentFile = config.age.secrets.authentik-env.path;
    authentikLdapEnvironmentFile = config.age.secrets.authentik-ldap-outpost-env.path;
    awsIdentityCenterReady = pkgs.writeShellScript "authentik-aws-identity-center-ready" ''
      [[ -n "''${AWS_IDENTITY_CENTER_ACS_URL:-}" ]]
      [[ -n "''${AWS_IDENTITY_CENTER_AUDIENCE:-}" ]]
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
        base_url = "https://auth.bylisa.dev";
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
        file = ../../security/agenix/secrets/atlas/authentik-env.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      authentik-ldap-outpost-env = {
        file = ../../security/agenix/secrets/atlas/authentik-ldap-outpost-env.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.authentik-ldap-outpost = {
      image = "ghcr.io/goauthentik/ldap:${config.services.authentik.authentikComponents.rust.version}";
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

    # AWS supplies these values only after IAM Identity Center is enabled and its
    # service-provider metadata is downloaded. Until both variables exist in
    # authentik-env.age, ExecCondition skips this blueprint without failing the
    # authentik deployment.
    forge.authentik.blueprints.aws-identity-center = {
      description = "Apply AWS IAM Identity Center Authentik SAML blueprint";
      file = awsIdentityCenterBlueprint;
      fileName = "aws-iam-identity-center.yaml";
      condition = "${awsIdentityCenterReady}";
    };

    systemd.services = {
      authentik.restartTriggers = [config.age.secrets.authentik-env.file];
      authentik-worker.restartTriggers = [config.age.secrets.authentik-env.file];
      docker-authentik-ldap-outpost.restartTriggers = [config.age.secrets.authentik-ldap-outpost-env.file];
    };

    networking.firewall.allowedTCPPorts = [636];
  };
}
