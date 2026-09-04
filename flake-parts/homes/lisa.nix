{
  config,
  inputs,
  ...
}: {
  flake.modules.homeManager.lisa = {
    imports = [
      inputs.onepassword-shell-plugins.hmModules.default
      config.flake.modules.homeManager.catppuccin
      config.flake.modules.homeManager.t3-code
      config.flake.modules.homeManager.security_agenix
      config.flake.modules.homeManager.ai-environment
      config.flake.modules.homeManager.cli-proxy-api-plus
      config.flake.modules.homeManager.xdg-extra
      ./_lisa
    ];
  };
}
