{lib, ...}: {
  options.network = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        lan = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Address on the home LAN, if the host has one.";
        };
        tailscale = lib.mkOption {
          type = lib.types.str;
          description = "Stable Tailscale address, used away from home and by other hosts.";
        };
        ssh = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              user = lib.mkOption {type = lib.types.str;};
              identityFile = lib.mkOption {
                type = lib.types.str;
                description = "Public key that selects the 1Password SSH agent identity.";
              };
            };
          });
          default = null;
          description = "How Lisa's workstations log in; set to generate their SSH host block.";
        };
      };
    });
    default = {};
    description = "Hosts that other features connect to; each host's own module sets its entry.";
  };
  # The mail server is not managed here, but Lisa's workstations reach it.
  config.network.mail = {
    tailscale = "100.121.88.128";
    ssh = {
      user = "root";
      identityFile = "~/.ssh/root@mail.pub";
    };
  };
}
