{
  config,
  inputs,
  lib,
  ...
}: let
  mkSystemModule = agenixModule: {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.forge.security.agenix;
    system = pkgs.stdenv.hostPlatform.system;
  in {
    imports = [agenixModule];

    options.forge.security.agenix.enable = lib.mkEnableOption ''
      agenix secret management

      References:
      - https://github.com/ryantm/agenix
      - https://nixos.wiki/wiki/Agenix
    '';

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        inputs.agenix.packages.${system}.default
        pkgs.age
      ];
      age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };
  };
in {
  options.secrets = with lib.types; {
    secretsPath = lib.mkOption {
      type = path;
      default = ./secrets;
      description = "Path to the actual secrets directory";
    };

    pubkeys = lib.mkOption {
      type = attrsOf (attrsOf anything);
      default = {};
      description = "Public keys used throughout the flake.";
    };

    pubkeysFile = lib.mkOption {
      type = path;
      default = ./_pubkeys.nix;
      description = "File used to construct the secrets.pubkeys option.";
    };

    extraPubkeys = lib.mkOption {
      type = attrsOf (attrsOf anything);
      default = {};
      description = "Additional public keys merged into secrets.pubkeys.";
    };
  };

  config = {
    secrets.pubkeys = (import config.secrets.pubkeysFile) // config.secrets.extraPubkeys;

    flake.modules = {
      nixos.security_agenix = mkSystemModule inputs.agenix.nixosModules.default;
      darwin.security_agenix = mkSystemModule inputs.agenix.darwinModules.default;
      homeManager.security_agenix = {
        config,
        lib,
        ...
      }: let
        cfg = config.forge.hm.security.agenix;
      in {
        imports = [inputs.agenix.homeManagerModules.default];

        options.forge.hm.security.agenix.enable = lib.mkEnableOption "agenix secret management";

        config = lib.mkIf cfg.enable {
          age.identityPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
        };
      };
    };

    flake-file.inputs.agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
