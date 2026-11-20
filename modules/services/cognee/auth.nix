let
  domain = "cognee.local.bylisa.dev";
  oidcSecret = ../../security/agenix/secrets/shared/cognee-oidc-env.age;
in {
  nixos.atlas = {
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
                url: https://${domain}/auth/callback
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
            meta_launch_url: https://${domain}/
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
            external_host: https://${domain}
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
            meta_launch_url: https://${domain}/graph/
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
      file = oidcSecret;
      mode = "0400";
    };
    forge.authentik.blueprints.cognee = {
      description = "Apply Cognee Authentik OAuth2/OIDC blueprint";
      file = blueprint;
      environmentFiles = [config.age.secrets.cognee-oidc-env.path];
      restartTriggers = [oidcSecret];
      embeddedOutpostProvider = "Cognee graph";
    };
  };
}
