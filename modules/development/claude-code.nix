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
        env = {
          # Nix installs and updates Claude Code.
          DISABLE_AUTOUPDATER = "1";
          # AGENTS.md: delegated agents do not start their own.
          CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
          # Bash commands, hooks and stdio MCP servers start without credentials
          # from Claude's environment; GitHub tokens are kept.
          CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1";
        };
      };
    };
  };
}
