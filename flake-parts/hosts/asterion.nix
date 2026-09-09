{
  config,
  inputs,
  ...
}: {
  forge.hosts.asterion = {
    class = "nixos";
    system = "aarch64-linux";
    module = config.forge.modules.nixos.asterion;
  };
  forge.modules.nixos.asterion = {
    imports = [
      inputs.nixos-apple-silicon.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
    ];
    home-manager = {
      backupFileExtension = "before-nix-home-manager";
      useGlobalPkgs = true;
      useUserPackages = true;
    };
    home-manager.users.lisa.imports = [
      config.forge.modules.homeManager."lisa@asterion"
    ];
  };

  flake-file.inputs.nixos-apple-silicon = {
    url = "github:nix-community/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
