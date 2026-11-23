{
  home.lisa = {
    programs.claude-code = {
      enable = true;
      mutableSettings = true;
      settings = {
        # Servers from a repository's .mcp.json start only after approval.
        enableAllProjectMcpServers = false;
        # Cognee holds memory across sessions, as for Codex, whose memories are off too.
        autoMemoryEnabled = false;
      };
    };
  };
}
