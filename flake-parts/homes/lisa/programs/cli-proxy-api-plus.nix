{config, ...}: let
  proxy = config.forge.modules.homeManager.cli-proxy-api-plus;
in {
  # Optional composition: none of the current homes selects the local proxy.
  forge.modules.homeManager.lisa-proxy = {config, ...}: {
    imports = [proxy];
    services.cli-proxy-api-plus = {
      integrations.enable = true;
      openrouter = {
        enable = true;
        apiKeyFile = "${config.xdg.configHome}/cli-proxy-api-plus/openrouter-api-key";
        models = [
          {
            name = "openrouter/auto";
            alias = "auto";
            display-name = "OpenRouter Auto";
          }
          {
            name = "z-ai/glm-5.3-flash";
            alias = "glm-5.3-flash";
            display-name = "GLM 5.3 Flash";
          }
        ];
      };
      integrations.models = ["gpt-5.6-sol" "openrouter/auto" "openrouter/glm-5.3-flash"];
    };
  };
}
