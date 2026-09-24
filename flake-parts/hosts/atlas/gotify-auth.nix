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

        - model: authentik_events.notificationtransport
          id: gotify-transport
          identifiers:
            name: Gotify
          attrs:
            mode: webhook
            webhook_url: !Env GOTIFY_WEBHOOK_URL
            send_once: true
            webhook_mapping_body: null
            webhook_mapping_headers: null

        - model: authentik_events.notificationrule
          id: gotify-events
          identifiers:
            name: Gotify authentication events
          attrs:
            severity: notice
            destination_group: !Find [authentik_core.group, [name, "authentik Admins"]]
            destination_event_user: false
            transports:
              - !KeyOf gotify-transport

        - model: authentik_policies_event_matcher.eventmatcherpolicy
          id: gotify-login
          identifiers:
            name: Gotify login
          attrs:
            action: login
        - model: authentik_policies_event_matcher.eventmatcherpolicy
          id: gotify-login-failed
          identifiers:
            name: Gotify login failed
          attrs:
            action: login_failed
        - model: authentik_policies_event_matcher.eventmatcherpolicy
          id: gotify-logout
          identifiers:
            name: Gotify logout
          attrs:
            action: logout

        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf gotify-events
            policy: !KeyOf gotify-login
            order: 0
          attrs:
            enabled: true
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf gotify-events
            policy: !KeyOf gotify-login-failed
            order: 1
          attrs:
            enabled: true
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf gotify-events
            policy: !KeyOf gotify-logout
            order: 2
          attrs:
            enabled: true
    '';
  in {
    age.secrets.gotify-webhook-env = {
      file = ../../agenix/secrets/atlas/gotify-webhook-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    age.secrets.gotify-oidc-env = {
      file = ../../agenix/secrets/shared/gotify-oidc-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.authentik-gotify-blueprint = {
      description = "Apply Gotify Authentik OIDC and notification blueprint";
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
          config.age.secrets.gotify-webhook-env.path
        ];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint} %S/authentik/blueprints/gotify.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint gotify.yaml";
      };
      restartTriggers = [
        ../../agenix/secrets/atlas/authentik-env.age
        ../../agenix/secrets/shared/gotify-oidc-env.age
        ../../agenix/secrets/atlas/gotify-webhook-env.age
      ];
    };
  };
}
