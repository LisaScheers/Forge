localFlake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.forge.codex;
  tomlFormat = pkgs.formats.toml {};
  skillType = lib.types.either lib.types.lines lib.types.path;
  bundledSkills = {
    audit-codex-history = ./skills/audit-codex-history;
    babysit-pr = ./skills/babysit-pr;
    file-pr = ./skills/file-pr;
    html-communication = ./skills/html-communication;
    nix-dependancies = ./skills/nix-dependancies;
    postplan-read = ./skills/postplan-read;
    lsl = ./skills/lsl;
    use-lsl-tester = ./skills/use-lsl-tester;
  };
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
      description = "Global instructions installed as CODEX_HOME/AGENTS.md.";
    };

    enableBundledSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the draft skills bundled with this module.";
    };

    extraSkills = lib.mkOption {
      type = lib.types.attrsOf skillType;
      default = {};
      description = "Additional Codex skills keyed by their skill directory name.";
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
        skills =
          lib.optionalAttrs cfg.enableBundledSkills bundledSkills
          // cfg.extraSkills;
      }
      // lib.optionalAttrs (cfg.settings != null) {
        inherit (cfg) settings;
      };
  };
}
