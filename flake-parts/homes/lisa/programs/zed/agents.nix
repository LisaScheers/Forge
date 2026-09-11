{
  forge.modules.homeManager.lisa = {
    programs.zed-editor.userSettings = {
      agent = {
        commit_message_instructions = "Use the Conventional Commits format: <type>(<scope>): <description>.";
        commit_message_model = {
          provider = "openrouter";
          model = "z-ai/glm-5.3-flash";
        };
      };
      language_models = {
        open_router = {
          api_url = "https://openrouter.ai/api/v1";
          available_models = [
            {
              name = "z-ai/glm-5.3-flash";
              display_name = "GLM 5.3 Flash";
              max_tokens = 1500000;
              supports_tools = true;
              supports_images = true;
            }
          ];
        };
      };
    };
  };
}
