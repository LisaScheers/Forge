{
  config,
  lib,
  ...
}: {
  options.sshRemotes = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    default = lib.mapAttrs (_: host: {
      HostName = host.tailscale;
      User = host.ssh.user;
      IdentityFile = host.ssh.identityFile;
      IdentitiesOnly = true;
      # Explicit, so a broader Host block in an included file cannot change it.
      Port = 22;
    }) (lib.filterAttrs (_: host: host.ssh != null) config.network);
    description = "SSH host blocks for every network entry that declares a login.";
  };
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
