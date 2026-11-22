{
  home.lisa = {pkgs, ...}: {
    programs.claude-code = {
      enable = true;
      # ai-proxy exports ANTHROPIC_BASE_URL for every shell, but the proxy holds
      # no Claude credentials, so Claude Code signs in to Anthropic directly.
      package = pkgs.symlinkJoin {
        name = "claude-code-direct-${pkgs.claude-code.version}";
        # Home Manager gates its plugin and MCP wiring on this version.
        inherit (pkgs.claude-code) version;
        paths = [pkgs.claude-code];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram "$out/bin/claude" --unset ANTHROPIC_BASE_URL
        '';
        meta.mainProgram = "claude";
      };
      mutableSettings = true;
      enableMcpIntegration = true;
      mcpServers.cognee = {
        type = "http";
        url = "https://cognee.local.bylisa.dev/mcp";
      };
    };
  };
}
