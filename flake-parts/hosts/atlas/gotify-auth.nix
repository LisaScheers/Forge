{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    blueprint = pkgs.writeText "authentik-gotify-blueprint.yaml" ''
      version: 1
      metadata:
        name: Gotify OAuth2/OIDC
      entries:
        - model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Gotify
          id: gotify-provider
          attrs:
            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
            invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
            signing_key: !Find [authentik_crypto.certificatekeypair, [name, "authentik Self-signed Certificate"]]
            client_type: confidential
            client_id: gotify
            client_secret: !Env GOTIFY_OIDC_CLIENTSECRET
            issuer_mode: per_provider
            grant_types:
              - authorization_code
            redirect_uris:
              - matching_mode: strict
                url: https://gotify.bylisa.dev/auth/oidc/callback
              - matching_mode: strict
                url: gotify://oidc/callback
            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]

        - model: authentik_core.application
          id: gotify-application
          identifiers:
            slug: gotify
          attrs:
            name: Gotify
            provider: !KeyOf gotify-provider
            meta_launch_url: https://gotify.bylisa.dev

        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf gotify-application
            group: !Find [authentik_core.group, [name, "authentik Admins"]]
            order: 0
          attrs:
            enabled: true
    '';
  in {
    age.secrets.gotify-oidc-env = {
      file = ../../agenix/secrets/shared/gotify-oidc-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.authentik-gotify-blueprint = {
      description = "Apply Gotify Authentik OAuth2/OIDC blueprint";
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
          config.age.secrets.authentik-env.path
          config.age.secrets.gotify-oidc-env.path
        ];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint} %S/authentik/blueprints/gotify.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint gotify.yaml";
      };
      restartTriggers = [
        ../../agenix/secrets/atlas/authentik-env.age
        ../../agenix/secrets/shared/gotify-oidc-env.age
      ];
    };
  };
}
