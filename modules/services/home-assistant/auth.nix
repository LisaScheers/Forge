{
  nixos.nook = {pkgs, ...}: {
    services.home-assistant = {
      customComponents = [pkgs.nookApps.home-assistant-custom-components.auth_oidc];
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
          # Lisa's OIDC subject is already linked to her existing HA owner.
          automatic_user_linking = false;
          automatic_person_creation = false;
          default_redirect = true;
        };
      };
    };
  };

  nixos.atlas = {
    forge.authentik.blueprints.home-assistant = {
      description = "Apply Home Assistant Authentik OIDC provider and owner policy";
      file = ../../../services/home-assistant/authentik.yaml;
    };
  };
}
