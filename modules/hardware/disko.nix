{inputs, ...}: {
  nixos.base.imports = [inputs.disko.nixosModules.disko];
  flake-file.inputs.disko.url = "github:nix-community/disko";
}
