{
  home.ai-environment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.forge.ai-skills;
    skillType = lib.types.either lib.types.lines lib.types.path;
    # scan the skills directory for all skills, and make them available to the user
    bundledSkills = builtins.listToAttrs (map (skill: {
      name = skill;
      value =
        if skill == "visualize"
        then "${import ../../../packages/visualize-skill/package.nix {
          inherit pkgs;
          src = ./skills/visualize;
        }}"
        else ./skills/${skill};
    }) (builtins.attrNames (builtins.readDir ./skills)));
    pstackSkills = builtins.listToAttrs (map (skill: {
      name = skill;
      value = ./pstack/skills/${skill};
    }) (builtins.attrNames (builtins.readDir ./pstack/skills)));
    tstack = pkgs.fetchFromGitHub {
      owner = "t3dotgg";
      repo = "tstack";
      rev = "11e37a74d0a6868c121cd0910ab2b3bd9873b92a";
      hash = "sha256-1N0fxvcM44NcGOZeYJiX/EAJuI9GoAj5rEXmu7mJc3w=";
    };
    # Bundled file-pr and babysit-pr replace tstack's versions, which full-send calls by name.
    tstackSkills = lib.genAttrs ["council" "full-send" "full-stop" "sol-loop"] (skill: "${tstack}/skills/${skill}");
    effectiveSkills =
      lib.optionalAttrs cfg.enableBundledSkills bundledSkills
      // cfg.extraSkills;
    effectiveAgentSkills =
      lib.optionalAttrs cfg.enableTstackSkills tstackSkills
      // effectiveSkills;
    effectiveCodexSkills =
      effectiveAgentSkills
      // lib.optionalAttrs cfg.enablePstackSkills pstackSkills;
  in {
    options.forge.ai-skills = {
      enable = (lib.mkEnableOption "the declarative ai skills environment") // {default = true;};

      agentsFile = lib.mkOption {
        type = lib.types.either lib.types.lines lib.types.path;
        default = ./AGENTS.md;
        defaultText = lib.literalExpression "./AGENTS.md";
        description = "Global instructions shared by Codex, Claude Code, Antigravity CLI and GitHub Copilot CLI.";
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

      enableTstackSkills = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install Theo's council, full-send, full-stop, and sol-loop skills in Codex and Claude Code.";
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

      programs = {
        codex = {
          context = cfg.agentsFile;
          skills = effectiveCodexSkills;
        };

        claude-code = {
          context = cfg.agentsFile;
          skills = effectiveAgentSkills;
        };

        antigravity-cli = {
          context.GEMINI = cfg.agentsFile;
          skills = effectiveSkills;
        };

        github-copilot-cli = {
          context = cfg.agentsFile;
          skills = effectiveSkills;
        };
      };
    };
  };
}
