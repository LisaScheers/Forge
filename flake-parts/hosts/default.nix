{
  config,
  inputs,
  ...
}: {
  forge.modules = {
    nixos.base = {
      imports = [
        inputs.disko.nixosModules.disko
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
        config.forge.modules.darwin.networking
        config.forge.modules.darwin.security_agenix
        config.forge.modules.darwin.security_sops
      ];
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [config.flake.overlays.default];
    };
  };

  flake-file.inputs.disko.url = "github:nix-community/disko";
}
