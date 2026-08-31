{
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
