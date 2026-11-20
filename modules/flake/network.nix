{lib, ...}: {
  options.network = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        lan = lib.mkOption {
          type = lib.types.str;
          description = "Address on the home LAN.";
        };
        tailscale = lib.mkOption {
          type = lib.types.str;
          description = "Stable Tailscale address, used away from home and by other hosts.";
        };
      };
    });
    default = {};
    description = "Addresses of hosts that other features connect to; each host's networking module sets its own.";
  };
}
