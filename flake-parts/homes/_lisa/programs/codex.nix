{
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
}
