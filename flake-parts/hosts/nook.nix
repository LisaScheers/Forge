{
  config,
  inputs,
  ...
}: {
  forge.hosts.nook = {
    class = "nixos";
    system = "x86_64-linux";
    module = config.forge.modules.nixos.nook;
  };
  flake.checks.x86_64-linux.nook = config.flake.nixosConfigurations.nook.config.system.build.toplevel;
  forge.modules.nixos.nook = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    home-manager = {
      backupFileExtension = "before-nix-home-manager";
      useGlobalPkgs = true;
      useUserPackages = true;
    };
    home-manager.users.lisa.imports = [
      config.forge.modules.homeManager."lisa@nook"
    ];
  };
}
