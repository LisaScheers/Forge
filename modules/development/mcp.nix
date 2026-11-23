# The MCP servers Lisa's agents share, declared once and rendered for each
# client. REA adds its own server in rea.nix.
{lib, ...}: let
  cognee.url = "https://cognee.local.bylisa.dev/mcp";
  # Codex replaces a whole server table when settings name it, so its extra
  # fields are merged here rather than in a second declaration.
  codexCognee =
    cognee
    // {
      startup_timeout_sec = 30;
      tool_timeout_sec = 600;
      tools.forget.approval_mode = "prompt";
    };
  clerk = {
    enabled = true;
    url = "https://mcp.clerk.com/mcp";
  };
  webmcp = pkgs: {
    command = lib.getExe pkgs.webmcp;
    args = ["--mcp"];
  };
  # `codex -c` takes one dotted key per flag, with TOML values.
  codexOverrides = prefix: attrs:
    lib.concatLists (lib.mapAttrsToList (
        name: value:
          if builtins.isAttrs value
          then codexOverrides "${prefix}.${name}" value
          else ["-c" "${prefix}.${name}=${builtins.toJSON value}"]
      )
      attrs);
in {
  overlays.webmcp = final: _prev: {
    webmcp = final.callPackage ../../packages/webmcp/package.nix {};
  };

  perSystem = {pkgs, ...}: {
    packages.webmcp = pkgs.webmcp;
  };

  home.lisa = {pkgs, ...}: {
    programs = {
      mcp = {
        enable = true;
        # Clerk's tools change a third-party account, so every client asks first.
        servers = {
          clerk_mcp = clerk;
          webmcp = webmcp pkgs;
        };
      };

      claude-code = {
        enableMcpIntegration = true;
        mcpServers.cognee = cognee // {type = "http";};
        # Load MCP tool schemas only when a search finds them, whatever their size.
        settings.env.ENABLE_TOOL_SEARCH = "true";
      };

      codex = {
        enableMcpIntegration = true;
        settings.mcp_servers = {
          cognee = codexCognee;
          clerk_mcp = clerk // {default_tools_approval_mode = "prompt";};
          webmcp = webmcp pkgs // {startup_timeout_sec = 60;};
        };
      };
    };
  };

  # Nook's remote-control service passes the same Cognee server as flags.
  nixos.nook = {pkgs, ...}: {
    systemd.services.codex.serviceConfig.ExecStart = lib.escapeShellArgs (
      ["${pkgs.codex}/bin/codex"]
      ++ codexOverrides "mcp_servers.cognee" codexCognee
      ++ ["remote-control"]
    );
  };
}
