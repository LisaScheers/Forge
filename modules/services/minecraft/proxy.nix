{config, ...}: let
  nook = config.network.nook;
in {
  nixos.atlas = {pkgs, ...}: {
    # Keep the public address while the world runs on Nook over Tailscale.
    systemd.services.atm10-8-0.enable = false;
    networking.firewall.allowedTCPPorts = [25565];

    systemd.sockets.minecraft = {
      wantedBy = ["sockets.target"];
      listenStreams = ["25565"];
    };
    systemd.services.minecraft = {
      requires = ["tailscaled.service"];
      wants = ["network-online.target"];
      after = ["tailscaled.service" "network-online.target"];
      serviceConfig = {
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${nook.tailscale}:25565";
        DynamicUser = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
