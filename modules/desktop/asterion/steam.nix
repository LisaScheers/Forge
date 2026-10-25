{inputs, ...}: {
  flake-file.inputs.steam-asahi = {
    url = "github:sm-idk/steam-asahi";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixos.asterion = {
    imports = [inputs.steam-asahi.nixosModules.default];
    programs.steam-asahi.enable = true;
    hardware.steam-hardware.enable = true;
    users.users.lisa.extraGroups = ["kvm"];
  };
}
