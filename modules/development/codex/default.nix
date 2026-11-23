{inputs, ...}: {
  home.lisa = {lib, ...}: {
    programs.codex = {
      enable = true;
      mutableSettings = true;

      settings = {
        # Writes stay inside the workspace and escalation asks first; network
        # stays on for builds, git and package lookups. agent-policy.nix adds
        # the commands that always ask.
        approval_policy = "on-request";
        sandbox_mode = "workspace-write";
        sandbox_workspace_write.network_access = true;
        model_reasoning_effort = lib.mkDefault "high";
        personality = "pragmatic";
        # Nix installs and updates Codex.
        check_for_update_on_startup = false;

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

      # `codex --profile full` restores unsandboxed, unprompted runs for one session.
      profiles.full = {
        approval_policy = "never";
        sandbox_mode = "danger-full-access";
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
