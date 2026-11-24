{inputs, ...}: {
  home.lisa = {lib, ...}: {
    programs.codex = {
      enable = true;
      mutableSettings = true;

      settings = {
        # Full access with no approval prompts, as for every agent (agent-policy.nix).
        approval_policy = "never";
        sandbox_mode = "danger-full-access";
        model_reasoning_effort = lib.mkDefault "high";
        personality = "pragmatic";
        # Nix installs and updates Codex.
        check_for_update_on_startup = false;

        agents.max_concurrent_threads_per_session = 10;

        # The TUI footer: model and effort, context used, and plan limits.
        tui.status_line = ["model-with-reasoning" "context-used" "five-hour-limit" "weekly-limit"];

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
  };
  overlays.codex = final: _prev: {
    codex = inputs.codex-cli-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.codex-cli-nix = {
    url = "github:sadjow/codex-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
