{
  config,
  inputs,
  ...
}: let
  reaModule = config.home.rea;
in {
  overlays.rea = final: _prev: {
    rea-unwrapped = final.callPackage ../../packages/rea/package.nix {};
    rea = final.callPackage ../../packages/rea/tools.nix {
      rea = final.rea-unwrapped;
      browser = inputs.helium.packages.${final.stdenv.hostPlatform.system}.default;
      pwndbg = inputs.pwndbg.packages.${final.stdenv.hostPlatform.system}.pwndbg;
    };
  };
  flake-file.inputs.pwndbg = {
    url = "github:pwndbg/pwndbg/2026.09.15";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  perSystem = {pkgs, ...}: let
    testHome = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        reaModule
        {
          home.username = "rea-test";
          home.homeDirectory =
            if pkgs.stdenv.hostPlatform.isDarwin
            then "/Users/rea-test"
            else "/home/rea-test";
          home.stateVersion = "26.11";
          programs.codex.enable = true;
          programs.codex.package = null;
          forge.rea.environment.REA_ANALYSIS_PROVIDER = "kuna";
        }
      ];
    };
  in {
    packages.rea = pkgs.rea;
    checks.rea = pkgs.rea;
    checks.rea-codex-config =
      pkgs.runCommand "rea-codex-config" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        python3 - ${testHome.config.home.file.".codex/config.toml".source} <<'PY'
        import pathlib, sys, tomllib
        with open(sys.argv[1], "rb") as source:
            server = tomllib.load(source)["mcp_servers"]["rea"]
        assert pathlib.Path(server["command"]).is_file()
        assert server["command"].endswith("/scripts/rea.mjs")
        assert server["args"] == ["mcp"]
        assert server["env"]["REA_ANALYSIS_PROVIDER"] == "kuna"
        assert pathlib.Path(server["env"]["REA_KUNA_COMMAND"]).is_file()
        assert pathlib.Path(server["env"]["PATH"].split(":")[0], "rea").is_file()
        assert server["startup_timeout_sec"] == 30
        assert server["tool_timeout_sec"] == 600
        PY
        touch "$out"
      '';
  };

  home.lisa = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [reaModule];
    home.activation.syncReaConfig = lib.mkIf config.programs.codex.enable (
      lib.hm.dag.entryAfter ["seedCodexConfig"] ''
        run ${pkgs.python3.withPackages (ps: [ps.tomlkit])}/bin/python3 \
          ${./codex/sync-mcp-config.py} \
          ${lib.escapeShellArg config.home.homeDirectory}/.codex/config.toml \
          ${config.home.file.".codex/config.toml".source} rea
      ''
    );
  };

  home.rea = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.forge.rea;
    mcpServer = {
      # REA can verify the script's identity; a shell wrapper is opaque to doctor.
      command = "${cfg.package}/lib/node_modules/rea-agents/scripts/rea.mjs";
      args = ["mcp"];
      env =
        (cfg.package.environment or {})
        // {
          PATH = "${cfg.package}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        }
        // cfg.environment;
    };
  in {
    options.forge.rea = {
      enable = lib.mkEnableOption "REA reverse engineering tools" // {default = true;};
      package = lib.mkPackageOption pkgs "rea" {};
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example.GHIDRA_INSTALL_DIR = "/path/to/ghidra";
        description = "Environment passed to REA's MCP server, including optional analysis engine settings.";
      };
    };

    config = lib.mkIf cfg.enable {
      home.packages = [cfg.package];
      home.file = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        "Library/Application Support/rizin/cutter/plugins/python/rea_bridge.py".source = "${cfg.package}/lib/node_modules/rea-agents/bridge/cutter/rea_bridge.py";
      };
      xdg.dataFile = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        "rizin/cutter/plugins/python/rea_bridge.py".source = "${cfg.package}/lib/node_modules/rea-agents/bridge/cutter/rea_bridge.py";
      };
      programs.mcp = {
        enable = true;
        servers.rea = mcpServer;
      };
      programs.codex = {
        enableMcpIntegration = lib.mkDefault true;
        # Home Manager replaces each server table rather than merging its fields.
        settings.mcp_servers.rea =
          mcpServer
          // {
            startup_timeout_sec = 30;
            tool_timeout_sec = 600;
          };
        skills.reverse-engineer-anything = "${cfg.package}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";
      };
    };
  };
}
