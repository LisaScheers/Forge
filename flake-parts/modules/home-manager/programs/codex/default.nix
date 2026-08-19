localFlake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.forge.codex;
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
  options.forge.codex = {
    enable = lib.mkEnableOption "the declarative Codex environment";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.codex;
      defaultText = lib.literalExpression "pkgs.codex";
      description = "Codex package to install, or null to manage only its files.";
    };

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

    settings = lib.mkOption {
      type = lib.types.nullOr tomlFormat.type;
      default = null;
      description = ''
        Codex settings to manage as CODEX_HOME/config.toml. Leave null when
        Codex Desktop should continue to own its mutable project, plugin, and
        interface settings; Home Manager replaces this file rather than
        merging with an existing one.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.postplan-selfhosted];
    home.sessionVariables.POSTPLAN_API_URL = "https://plans.bylisa.dev";

    programs.codex =
      {
        enable = true;
        inherit (cfg) package;
        context = cfg.agentsFile;
        skills = effectiveCodexSkills;
      }
      // lib.optionalAttrs (cfg.settings != null) {
        inherit (cfg) settings;
      };

    programs.antigravity-cli = {
      enable = true;
      package = pkgs.antigravity-cli;
      skills = effectiveSkills;
    };

    programs.github-copilot-cli = {
      enable = true;
      package = pkgs.github-copilot-cli;
      context = cfg.agentsFile;
      skills = effectiveSkills;
      settings.autoUpdate = false;
    };
  };
}
