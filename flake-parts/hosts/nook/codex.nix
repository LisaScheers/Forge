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
        ExecStart = "${pkgs.codex}/bin/codex remote-control";
        Restart = "always";
        RestartSec = "15s";
        UMask = "0077";
      };
    };
  };
}
