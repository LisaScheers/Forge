{
  forge.modules.nixos.atlas = {pkgs, ...}: {
    # Keep the public address while the world runs on Nook over Tailscale.
    systemd.services.atm10-8-0.enable = false;
    networking.firewall.allowedTCPPorts = [25565];

    systemd.sockets.minecraft = {
      wantedBy = ["sockets.target"];
      listenStreams = ["25565"];
    };
    systemd.services.minecraft = {
      requires = ["tailscaled.service"];
      after = ["tailscaled.service" "network-online.target"];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 100.106.233.104:25565";
        DynamicUser = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
