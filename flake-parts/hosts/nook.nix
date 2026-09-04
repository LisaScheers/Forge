{config, ...}: {
  flake.modules.nixos.nook = {
    imports = [./_nook];

    home-manager.users.lisa.imports = [
      config.flake.modules.homeManager."lisa@nook"
    ];
  };
}
