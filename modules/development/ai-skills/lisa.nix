{
  config,
  inputs,
  ...
}: {
  # A flake input, so the daily flake.lock pull request also updates it.
  flake-file.inputs.anatomy = {
    url = "github:wheresryan22/anatomy";
    flake = false;
  };

  home.lisa = {
    imports = [config.home.ai-environment];
    forge.ai-skills.enable = true;
    forge.ai-skills.extraSkills.anatomy = "${inputs.anatomy}";
  };
}
