{
  config,
  lib,
  pkgs,
  ...
}: {
  services.tailscale = {
    enable = true;
    extraSetFlags = ["--accept-dns=false"];
    openFirewall = true;
  };

  networking = {
    nftables.enable = true;
    firewall = {
      enable = true;
      trustedInterfaces = [config.services.tailscale.interfaceName];
    };
  };

  # Keep tailscaled and container networking on the native nftables backend.
  systemd.services = {
    tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];
  } // lib.optionalAttrs config.virtualisation.docker.enable {
    docker.path = [pkgs.nftables];
  };

  virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
    firewall-backend = "nftables";
  };
}
