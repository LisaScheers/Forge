{
  config,
  inputs,
  ...
}: let
  lisaHome = config.flake.modules.homeManager."lisa@vega";
in {
  flake.modules.darwin.vega = {pkgs, ...}: {
    imports = [
      ./_vega
      (import ./_vega/homebrew.nix {inherit inputs;})
      (import ./_vega/comicCodeNerdFont.nix {inherit inputs pkgs;})
    ];

    users.users.lisa.home = "/Users/lisa";
    home-manager.users.lisa.imports = [lisaHome];
  };

  flake-file.inputs = {
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    comic-code-fonts = {
      url = "github:LisaScheers/comic-code-fonts";
      flake = false;
    };
  };
}
