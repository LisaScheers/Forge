{
  forge.modules.nixos.nook = {pkgs, ...}: {
    systemd.services.codex = {
      description = "Codex app server with remote control";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "systemd-tmpfiles-setup.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects"];
      path = ["/etc/profiles/per-user/codex" "/run/current-system/sw"];
      # Login and pairing share the same state as the foreground server.
      environment = {
        HOME = "/home/codex";
        CODEX_HOME = "/home/codex/.codex";
      };
      serviceConfig = {
        Type = "simple";
        User = "codex";
        Group = "users";
        WorkingDirectory = "/home/codex";
        # Run in the foreground so systemd owns startup and crash recovery.
        ExecStart = ''${pkgs.codex}/bin/codex -c 'mcp_servers.cognee.url="https://cognee.local.bylisa.dev/mcp"' -c 'mcp_servers.cognee.startup_timeout_sec=30' -c 'mcp_servers.cognee.tool_timeout_sec=600' -c 'mcp_servers.cognee.tools.forget.approval_mode="prompt"' remote-control'';
        Restart = "always";
        RestartSec = "15s";
        UMask = "0077";
      };
    };
  };
}
