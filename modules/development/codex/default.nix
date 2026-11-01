{ inputs, ... }: {
  home."lisa" = { lib, ... }: {
    programs = {
      codex = {
        enable = true;
        enableMcpIntegration = true;
        mutableSettings = true;

        settings = {
          approval_policy = "never";
          sandbox_mode = "danger-full-access";
          model_reasoning_effort = lib.mkDefault "high";
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
}
