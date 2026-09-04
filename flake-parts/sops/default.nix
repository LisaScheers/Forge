{inputs, ...}: let
  mkModule = sopsModule: {
    config,
    lib,
    ...
  }: let
    cfg = config.forge.security.sops;
  in {
    imports = [sopsModule];

    options.forge.security.sops = {
      enable = lib.mkEnableOption "sops-nix secret management";

      ageSshKeyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["/etc/ssh/ssh_host_ed25519_key"];
        description = "SSH private-key paths used as age identities at activation time.";
      };
    };

    config = lib.mkIf cfg.enable {
      sops.age.sshKeyPaths = lib.mkDefault cfg.ageSshKeyPaths;
    };
  };
in {
  flake.modules = {
    nixos.security_sops = mkModule inputs.sops-nix.nixosModules.sops;
    darwin.security_sops = mkModule inputs.sops-nix.darwinModules.sops;
  };

  flake-file.inputs.sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
