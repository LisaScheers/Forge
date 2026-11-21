{
  nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    blueprint = pkgs.writeText "authentik-postplan-blueprint.yaml" ''
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
            signing_key: !Find [authentik_crypto.certificatekeypair, [name, "authentik Self-signed Certificate"]]
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
  in {
    forge.authentik.blueprints.postplan = {
      description = "Apply PostPlan Authentik OAuth2/OIDC blueprint";
      file = blueprint;
      environmentFiles = [config.age.secrets.postplan-env.path];
      restartTriggers = [config.age.secrets.postplan-env.file];
    };
  };
}
