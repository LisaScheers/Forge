{inputs, ...}: let
  deployedPackages = inputs.nixpkgs-nook-apps.legacyPackages.x86_64-linux;
in {
  nixos.nook.services.home-assistant = {
    customComponents = [deployedPackages.home-assistant-custom-components.auth_oidc];
    config.auth_oidc = {
      client_id = "home-assistant";
      discovery_url = "https://auth.bylisa.dev/application/o/home-assistant/.well-known/openid-configuration";
      display_name = "Authentik";
      groups_scope = "home-assistant";
      roles = {
        admin = "home-assistant-owners";
        user = "home-assistant-owners";
      };
      features = {
        # Disable after Lisa's first OIDC login links her existing HA owner.
        automatic_user_linking = true;
        automatic_person_creation = false;
        default_redirect = true;
      };
    };
  };

  nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
    systemd.services.authentik-home-assistant-blueprint = {
      description = "Apply Home Assistant Authentik OIDC provider and owner policy";
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
        EnvironmentFile = [config.age.secrets.authentik-env.path];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${../../services/home-assistant/authentik.yaml} %S/authentik/blueprints/home-assistant.yaml";
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint home-assistant.yaml";
      };
      restartTriggers = [../security/agenix/secrets/atlas/authentik-env.age];
    };
  };
}
