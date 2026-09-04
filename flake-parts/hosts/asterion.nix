{
  config,
  inputs,
  ...
}: {
  flake.modules.nixos.asterion = {
    imports = [./_asterion];

    home-manager.users.lisa.imports = [
      config.flake.modules.homeManager."lisa@asterion"
    ];
  };

  flake-file.inputs.nixos-apple-silicon = {
    url = "github:nix-community/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
