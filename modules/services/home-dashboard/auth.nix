{config, ...}: {
  nixos.atlas.forge.authentik.blueprints.home-dashboard = {
    description = "Apply the dashboard Authentik provider";
    file = config.flake.lib.appBlueprint ../../../services/home-dashboard;
    embeddedOutpostProvider = "Home dashboard";
  };
}
