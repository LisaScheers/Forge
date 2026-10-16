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

    options.forge.security.agenix.enable =
      lib.mkEnableOption ''
        agenix secret management

        References:
        - https://github.com/ryantm/agenix
        - https://nixos.wiki/wiki/Agenix
      ''
      // {default = true;};

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

    extraPubkeys = lib.mkOption {
      type = attrsOf (attrsOf anything);
      default = {};
      description = "Additional public keys merged into secrets.pubkeys.";
    };
  };

  config = {
    secrets.pubkeys = config.secrets.extraPubkeys;

    nixos.base.imports = [config.nixos.agenix];
    darwin.base.imports = [config.darwin.agenix];
    home.lisa-cli.imports = [inputs.agenix.homeManagerModules.default];
    nixos.agenix = mkSystemModule inputs.agenix.nixosModules.default;
    darwin.agenix = mkSystemModule inputs.agenix.darwinModules.default;
    home.agenix = {
      config,
      lib,
      ...
    }: let
      cfg = config.forge.hm.security.agenix;
    in {
      imports = [inputs.agenix.homeManagerModules.default];

      options.forge.hm.security.agenix.enable = (lib.mkEnableOption "agenix secret management") // {default = true;};

      config = lib.mkIf cfg.enable {
        age.identityPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
      };
    };

    flake-file.inputs.agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
