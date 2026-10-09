{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: let
    secret = ../../agenix/secrets/shared/jellyfin-ldap-env.age;
    environmentFile = config.age.secrets.jellyfin-ldap-env.path;
    blueprint = pkgs.writeText "authentik-jellyfin-blueprint.yaml" ''
      version: 1
      metadata:
        name: Jellyfin LDAP authentication
      entries:
        - model: authentik_core.user
          identifiers:
            username: jellyfin-ldap
          id: jellyfin-ldap-user
          attrs:
            name: Jellyfin LDAP search
            type: service_account
            path: service-accounts
        - model: authentik_core.token
          identifiers:
            identifier: jellyfin-ldap-bind
          attrs:
            user: !KeyOf jellyfin-ldap-user
            intent: app_password
            expiring: false
            key: !Env JELLYFIN_LDAP_BIND_PASSWORD
        - model: authentik_core.group
          identifiers:
            name: jellyfin-users
          id: jellyfin-users
          attrs:
            users:
              - !Find [authentik_core.user, [username, lisa]]
              - !Find [authentik_core.user, [username, rose]]
        - model: authentik_providers_ldap.ldapprovider
          identifiers:
            name: Jellyfin LDAP
          id: jellyfin-provider
          attrs:
            authorization_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
            invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
            base_dn: dc=jellyfin,dc=bylisa,dc=dev
            certificate: !Find [authentik_crypto.certificatekeypair, [name, auth.bylisa.dev]]
            tls_server_name: auth.bylisa.dev
            bind_mode: direct
            search_mode: direct
            mfa_support: true
        - model: authentik_core.application
          identifiers:
            slug: jellyfin
          id: jellyfin-application
          attrs:
            name: Jellyfin
            provider: !KeyOf jellyfin-provider
            meta_launch_url: https://jellyfin.bylisa.dev/
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf jellyfin-application
            group: !KeyOf jellyfin-users
          attrs:
            order: 0
        - model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf jellyfin-application
            user: !KeyOf jellyfin-ldap-user
          attrs:
            order: 1
    '';
    attachProvider = pkgs.writeText "jellyfin-ldap-outpost.py" ''
      from guardian.shortcuts import assign_perm
      from authentik.core.models import User
      from authentik.outposts.models import Outpost
      from authentik.providers.ldap.models import LDAPProvider

      provider = LDAPProvider.objects.get(name="Jellyfin LDAP")
      assign_perm("authentik_providers_ldap.search_full_directory", User.objects.get(username="jellyfin-ldap"), provider)
      # Preserve the UniFi provider on the existing LDAP outpost.
      outpost = Outpost.objects.get(name="UniFi LDAP", type="ldap")
      outpost.providers.add(provider)
      outpost.save()
    '';
  in {
    age.secrets.jellyfin-ldap-env.file = secret;
    systemd.services.authentik-jellyfin-blueprint = {
      description = "Apply Jellyfin Authentik LDAP blueprint";
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
        EnvironmentFile = [config.age.secrets.authentik-env.path environmentFile];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint} %S/authentik/blueprints/jellyfin.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint jellyfin.yaml";
        ExecStartPost = "${config.services.authentik.authentikComponents.manage}/bin/manage.py shell -c 'exec(open(\"${attachProvider}\").read())'";
      };
      restartTriggers = [secret ../../agenix/secrets/atlas/authentik-env.age];
    };
    systemd.services.authentik = {
      serviceConfig.EnvironmentFile = [environmentFile];
      restartTriggers = [secret];
    };
    systemd.services.authentik-worker = {
      serviceConfig.EnvironmentFile = [environmentFile];
      restartTriggers = [secret];
    };
  };
}
