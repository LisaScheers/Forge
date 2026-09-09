{
  config,
  inputs,
  ...
}: {
  forge.modules.homeManager.lisa = {
    imports = [
      config.forge.modules.homeManager.lisa-shell
      inputs.onepassword-shell-plugins.hmModules.default
      config.forge.modules.homeManager.catppuccin
      config.forge.modules.homeManager.t3-code
      inputs.agenix.homeManagerModules.default
      config.forge.modules.homeManager.ai-environment
      config.forge.modules.homeManager.xdg-extra
    ];
  };
}
