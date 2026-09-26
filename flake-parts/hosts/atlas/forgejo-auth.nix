{
  forge.modules.nixos.atlas = {
    config,
    lib,
    pkgs,
    ...
  }: let
    oidcSecret = ../../agenix/secrets/atlas/forgejo-oidc-env.age;
    oidcEnvironmentFile = config.age.secrets.forgejo-oidc-env.path;
    blueprint = pkgs.writeText "authentik-forgejo-blueprint.yaml" ''
      version: 1

      metadata:
        name: Forgejo OAuth2/OIDC

      entries:
        - model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Forgejo
          id: forgejo-provider
          attrs:
            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
            invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
            signing_key: !Find [authentik_crypto.certificatekeypair, [name, "authentik Self-signed Certificate"]]
            client_type: confidential
            grant_types:
              - authorization_code
            client_id: forgejo
            client_secret: !Env FORGEJO_CLIENT_SECRET
            sub_mode: hashed_user_id
            redirect_uris:
              - matching_mode: strict
                url: https://git.bylisa.dev/user/oauth2/authentik/callback
            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'openid'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'email'"]]
              - !Find [authentik_providers_oauth2.scopemapping, [name, "authentik default OAuth Mapping: OpenID 'profile'"]]

        - model: authentik_core.application
          identifiers:
            slug: forgejo
          attrs:
            name: Forgejo
            provider: !KeyOf forgejo-provider
            meta_launch_url: https://git.bylisa.dev/user/oauth2/authentik
    '';
  in {
    age.secrets.forgejo-oidc-env = {
      file = oidcSecret;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.forgejo.settings.oauth2_client = {
      ENABLE_AUTO_REGISTRATION = false;
      ACCOUNT_LINKING = "login";
    };

    systemd.services.authentik-forgejo-blueprint = {
      description = "Apply Forgejo Authentik OAuth2/OIDC blueprint";
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
        EnvironmentFile = [config.age.secrets.authentik-env.path oidcEnvironmentFile];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint} %S/authentik/blueprints/forgejo.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint forgejo.yaml";
      };
      restartTriggers = [../../agenix/secrets/atlas/authentik-env.age oidcSecret];
    };

    # Authentik also reapplies discovered blueprints in its worker.
    systemd.services.authentik = {
      serviceConfig.EnvironmentFile = [oidcEnvironmentFile];
      restartTriggers = [oidcSecret];
    };
    systemd.services.authentik-worker = {
      serviceConfig.EnvironmentFile = [oidcEnvironmentFile];
      restartTriggers = [oidcSecret];
    };

    systemd.services.forgejo = {
      after = ["authentik.service" "nginx.service"];
      wants = ["authentik.service" "nginx.service"];
      serviceConfig = {
        LoadCredential = ["forgejo-oidc-env:${oidcEnvironmentFile}"];
        # OIDC discovery may still be warming up after Authentik starts.
        RestartSec = "5s";
      };
      restartTriggers = [oidcSecret];
      # The upstream pre-start creates app.ini and migrates the database first.
      # Updating the existing source preserves its ID and linked accounts.
      preStart = lib.mkAfter ''
        set -o pipefail
        source "$CREDENTIALS_DIRECTORY/forgejo-oidc-env"
        : "''${FORGEJO_CLIENT_SECRET:?Missing Forgejo OIDC client secret}"
        source_id="$(${lib.getExe config.services.forgejo.package} admin auth list | ${pkgs.gawk}/bin/awk '$2 == "authentik" { print $1 }')"
        auth_command=(add-oauth)
        if [[ -n "$source_id" ]]; then
          auth_command=(update-oauth --id "$source_id")
        fi
        ${lib.getExe config.services.forgejo.package} admin auth "''${auth_command[@]}" \
          --name authentik \
          --provider openidConnect \
          --key forgejo \
          --secret "$FORGEJO_CLIENT_SECRET" \
          --auto-discover-url https://auth.bylisa.dev/application/o/forgejo/.well-known/openid-configuration \
          --scopes email --scopes profile \
          --icon-url https://auth.bylisa.dev/static/dist/assets/icons/icon.png
        unset FORGEJO_CLIENT_SECRET
      '';
    };
  };
}
