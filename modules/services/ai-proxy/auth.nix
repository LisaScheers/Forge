{config, ...}: {
  nixos.atlas.forge.authentik.blueprints.ai-archive = {
    description = "Apply AI Archive's Lisa-only Authentik provider";
    file = config.flake.lib.appBlueprint ../../../services/ai-archive;
    embeddedOutpostProvider = "AI Archive";
  };
}
