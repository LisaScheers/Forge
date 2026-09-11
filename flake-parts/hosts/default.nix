{
  config,
  inputs,
  ...
}: {
  forge.modules = {
    nixos.base = {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.lix-module.nixosModules.default
        config.forge.modules.nixos.networking
        config.forge.modules.nixos.security_agenix
        config.forge.modules.nixos.security_sops
      ];
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [config.flake.overlays.default];
    };
    darwin.base = {
      imports = [
        inputs.nix-homebrew.darwinModules.nix-homebrew
        inputs.lix-module.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        config.forge.modules.darwin.networking
        config.forge.modules.darwin.security_agenix
        config.forge.modules.darwin.security_sops
      ];
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [config.flake.overlays.default];
    };
  };

  flake-file.inputs = {
    disko.url = "github:nix-community/disko";
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };
}
