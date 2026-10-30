{inputs, ...}: {
  home."lisa" = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Codex writes model choices and app integrations to config.toml. Keep the
    # generated settings as initial defaults, not a read-only live configuration.
    home.file.".codex/config.toml".target = ".codex/config.defaults.toml";
    home.activation.seedCodexConfig = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
      run ${pkgs.bash}/bin/bash ${./seed-codex-config.sh} \
        ${lib.escapeShellArg config.home.homeDirectory}/.codex/config.toml \
        ${config.home.file.".codex/config.toml".source}
    '';
    home.activation.syncCogneeConfig = lib.hm.dag.entryAfter ["seedCodexConfig"] ''
      run ${pkgs.python3.withPackages (ps: [ps.tomlkit])}/bin/python3 \
        ${./sync-mcp-config.py} \
        ${lib.escapeShellArg config.home.homeDirectory}/.codex/config.toml \
        ${config.home.file.".codex/config.toml".source} cognee
    '';

    programs = {
      codex = {
        enable = true;
        enableMcpIntegration = true;

        settings = {
          approval_policy = "never";
          sandbox_mode = "danger-full-access";
          model_reasoning_effort = "medium";
          personality = "pragmatic";

          agents.max_concurrent_threads_per_session = 10;

          features = {
            memories = false;
            prevent_idle_sleep = true;
          };

          memories = {
            generate_memories = false;
            use_memories = false;
          };

          mcp_servers.cognee = {
            url = "https://cognee.local.bylisa.dev/mcp";
            startup_timeout_sec = 30;
            tool_timeout_sec = 600;
            tools.forget.approval_mode = "prompt";
          };
        };
      };

      mcp = {
        enable = true;
        servers.clerk_mcp = {
          enabled = true;
          url = "https://mcp.clerk.com/mcp";
        };
      };
    };
  };
  overlays.codex = final: _prev: {
    codex = inputs.codex-cli-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.codex-cli-nix = {
    url = "github:sadjow/codex-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  perSystem = {pkgs, ...}: {
    checks.codex-mcp-config =
      pkgs.runCommand "codex-mcp-config" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.tomlkit]))];
      } ''
        cp ${./test_sync_mcp_config.py} test_sync_mcp_config.py
        cp ${./sync-mcp-config.py} sync-mcp-config.py
        python3 test_sync_mcp_config.py
        touch "$out"
      '';
  };
}
