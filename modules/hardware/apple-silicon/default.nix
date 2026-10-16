{inputs, ...}: {
  nixos.apple-silicon.imports = [inputs.nixos-apple-silicon.nixosModules.default];
  flake-file.inputs.nixos-apple-silicon = {
    url = "github:nix-community/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
