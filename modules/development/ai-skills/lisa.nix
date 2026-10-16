{config, ...}: {
  home."lisa" = {
    imports = [config.home.ai-environment];
    forge.ai-skills.enable = true;
  };
}
