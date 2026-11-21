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
  options.secrets.pubkeys = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = {};
    description = "Public keys used throughout the flake.";
  };

  config = {
    nixos.base.imports = [config.nixos.agenix];
    darwin.base.imports = [config.darwin.agenix];
    nixos.agenix = mkSystemModule inputs.agenix.nixosModules.default;
    darwin.agenix = mkSystemModule inputs.agenix.darwinModules.default;

    flake-file.inputs.agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
