{lib, ...}: {
  # Distinct from flake.deploy, the deploy-rs output that deploy.nix builds from this.
  options.deploy.hosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        sshUser = lib.mkOption {
          type = lib.types.str;
          description = "Account deploy-rs logs in as.";
        };
        hostname = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "SSH host to connect to.";
        };
        interactiveSudo = lib.mkEnableOption "prompting for sudo during activation";
      };
    }));
    default = {};
    description = "Hosts deploy-rs manages, set beside each host's output.";
  };
}
