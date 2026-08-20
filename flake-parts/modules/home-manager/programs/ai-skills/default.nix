localFlake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.forge.ai-skills;
  tomlFormat = pkgs.formats.toml {};
  skillType = lib.types.either lib.types.lines lib.types.path;
  # scan the skills directory for all skills, and make them available to the user
  bundledSkills = builtins.listToAttrs (map (skill: {
    name = skill;
    value = ./skills/${skill};
  }) (builtins.attrNames (builtins.readDir ./skills)));
  pstackSkills = builtins.listToAttrs (map (skill: {
    name = skill;
    value = ./pstack/skills/${skill};
  }) (builtins.attrNames (builtins.readDir ./pstack/skills)));
  effectiveSkills =
    lib.optionalAttrs cfg.enableBundledSkills bundledSkills
    // cfg.extraSkills;
  effectiveCodexSkills =
    effectiveSkills
    // lib.optionalAttrs cfg.enablePstackSkills pstackSkills;
in {
  options.forge.ai-skills = {
    enable = lib.mkEnableOption "the declarative ai skills environment";

    agentsFile = lib.mkOption {
      type = lib.types.either lib.types.lines lib.types.path;
      default = ./AGENTS.md;
      defaultText = lib.literalExpression "./AGENTS.md";
      description = "Global instructions shared by Codex and GitHub Copilot CLI.";
    };

    enableBundledSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the draft skills bundled with this module.";
    };

    enablePstackSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the separately maintained pstack skills in Codex.";
    };

    extraSkills = lib.mkOption {
      type = lib.types.attrsOf skillType;
      default = {};
      description = "Additional shared skills keyed by their skill directory name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.postplan-selfhosted];
    home.sessionVariables.POSTPLAN_API_URL = "https://plans.bylisa.dev";

    programs.codex = {
      context = cfg.agentsFile;
      skills = effectiveCodexSkills;
    };

    programs.antigravity-cli = {
      skills = effectiveSkills;
    };

    programs.github-copilot-cli = {
      context = cfg.agentsFile;
      skills = effectiveSkills;
    };
  };
}
