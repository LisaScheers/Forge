{lib, ...}: {
  options.deploy.hosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        sshUser = lib.mkOption {type = lib.types.str;};
        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSH host to connect to; defaults to the host's name.";
        };
        interactiveSudo = lib.mkEnableOption "prompting for sudo during activation";
      };
    });
    default = {};
    description = "Hosts deploy-rs manages, set beside each host's output.";
  };
}
