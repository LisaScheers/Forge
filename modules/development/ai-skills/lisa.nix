{config, ...}: {
  home."lisa" = {pkgs, ...}: {
    imports = [config.home.ai-environment];
    forge.ai-skills.enable = true;
    forge.ai-skills.extraSkills.anatomy = "${pkgs.fetchFromGitHub {
      owner = "wheresryan22";
      repo = "anatomy";
      rev = "1482e8469b0a9e0d8cc18ea2740a01423d29ae80";
      hash = "sha256-v6g6CBGc5p95wdyLJ+UeBuUtX4PMZza31mCz8tvhBjM=";
    }}";
  };
}
