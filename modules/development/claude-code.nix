{
  home.lisa = {
    programs.claude-code = {
      enable = true;
      mutableSettings = true;
      # Servers from a repository's .mcp.json start only after approval.
      settings.enableAllProjectMcpServers = false;
    };
  };
}
