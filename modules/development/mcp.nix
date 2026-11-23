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
    };
  clerk = {
    enabled = true;
    url = "https://mcp.clerk.com/mcp";
  };
  webmcp = pkgs: {
    command = lib.getExe pkgs.webmcp;
    args = ["--mcp"];
  };
  # Codex finds these servers' tools through tool search instead of loading
  # their schemas into every session, as Claude does with ENABLE_TOOL_SEARCH.
  deferred = {omit_tools_from = ["direct"];};
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
          cognee = codexCognee // deferred;
          clerk_mcp = clerk // deferred;
          webmcp = webmcp pkgs // deferred // {startup_timeout_sec = 60;};
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
