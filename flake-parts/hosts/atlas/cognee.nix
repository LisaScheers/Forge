{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    blueprint = pkgs.writeText "authentik-cognee-blueprint.yaml" ''
      version: 1
      metadata:
        name: Cognee MCP OAuth2/OIDC
      entries:
        - model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Cognee
          id: cognee-provider
          attrs:
            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
            invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
            signing_key: !Find [authentik_crypto.certificatekeypair, [name, "authentik Self-signed Certificate"]]
            client_type: confidential
            client_id: cognee
            client_secret: !Env COGNEE_OIDC_CLIENT_SECRET
            grant_types: [authorization_code, refresh_token]
            redirect_uris:
              - matching_mode: strict
                url: https://cognee.local.bylisa.dev/auth/callback
            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'offline_access'"]]
        - model: authentik_core.application
          identifiers:
            slug: cognee
          id: cognee-application
          attrs:
            name: Cognee memory
            provider: !KeyOf cognee-provider
            meta_launch_url: https://cognee.local.bylisa.dev/
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf cognee-application
            group: !Find [authentik_core.group, [name, authentik Admins]]
            order: 0
          attrs:
            enabled: true
        - model: authentik_providers_proxy.proxyprovider
          identifiers:
            name: Cognee graph
          id: cognee-graph-provider
          attrs:
            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
            invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
            external_host: https://cognee.local.bylisa.dev
            mode: forward_single
            intercept_header_auth: false
            access_token_validity: minutes=5
        - model: authentik_core.application
          identifiers:
            slug: cognee-graph
          id: cognee-graph-application
          attrs:
            name: Cognee graph
            provider: !KeyOf cognee-graph-provider
            meta_launch_url: https://cognee.local.bylisa.dev/graph/
            policy_engine_mode: all
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf cognee-graph-application
            group: !Find [authentik_core.group, [name, authentik Admins]]
            order: 0
          attrs:
            enabled: true
    '';
  in {
    age.secrets.cognee-oidc-env = {
      file = ../../agenix/secrets/shared/cognee-oidc-env.age;
      mode = "0400";
    };
    systemd.services.authentik-cognee-blueprint = {
      description = "Apply Cognee Authentik OAuth2/OIDC blueprint";
      wantedBy = ["multi-user.target"];
      requiredBy = ["authentik.service"];
      before = ["authentik.service"];
      after = ["authentik-migrate.service"];
      requires = ["authentik-migrate.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
        User = "authentik";
        StateDirectory = "authentik";
        WorkingDirectory = "%S/authentik";
        EnvironmentFile = [config.age.secrets.authentik-env.path config.age.secrets.cognee-oidc-env.path];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = ["${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint} %S/authentik/blueprints/cognee.yaml"];
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint cognee.yaml";
        # Preserve other applications registered with the embedded outpost.
        ExecStartPost = ''${config.services.authentik.authentikComponents.manage}/bin/manage.py shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='Cognee graph')); outpost.save()"'';
      };
      restartTriggers = [../../agenix/secrets/shared/cognee-oidc-env.age];
    };
  };
}
