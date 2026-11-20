{
  config,
  inputs,
  withSystem,
  ...
}: let
  proxy = config.home.cli-proxy-api-plus;
in {
  # Opt-in: runs the gateway locally instead of using Nook's. No home imports
  # it today; the check below keeps it building so it stays usable.
  flake.checks.x86_64-linux.lisa-proxy-profile = withSystem "x86_64-linux" ({pkgs, ...}:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        config.home.lisa-proxy
        {
          home.username = "lisa";
          home.homeDirectory = "/home/lisa";
          home.stateVersion = "26.11";
        }
      ];
    })
    .activationPackage);
  home.lisa-proxy = {config, ...}: {
    imports = [proxy];
    services.cli-proxy-api-plus = {
      enable = true;
      integrations.enable = false;
      openrouter = {
        enable = true;
        apiKeyFile = "${config.xdg.configHome}/cli-proxy-api-plus/openrouter-api-key";
        models = [
          {
            name = "z-ai/glm-5.3-flash";
            alias = "glm-5.3-flash";
            display-name = "GLM 5.3 Flash";
          }
        ];
      };
      integrations.models = ["openrouter/glm-5.3-flash"];
      integrations.defaultModel = "openrouter/glm-5.3-flash";
    };
  };
}
