# This flake.nix file is auto-generated.
# The source of truth is merged from flake-parts modules under modules/.
# Regenerate with: nix run .#write-flake
# https://flake-file.denful.dev/
{
  description = "Multi-host Nix configuration for Darwin and NixOS";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    anatomy = {
      url = "github:wheresryan22/anatomy";
      flake = false;
    };
    antigravity-cli = {
      url = "github:selfhost-it/antigravity-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    authentik-nix.url = "github:nix-community/authentik-nix";
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comic-code-fonts = {
      url = "github:LisaScheers/comic-code-fonts";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv.url = "github:cachix/devenv";
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    disko.url = "github:nix-community/disko";
    flake-file.url = "github:denful/flake-file";
    flake-parts.url = "github:hercules-ci/flake-parts";
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    import-tree.url = "github:denful/import-tree";
    movie-night.url = "github:LisaScheers/movie-night";
    nix-auto-follow = {
      url = "github:fzakaria/nix-auto-follow";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-honeypot = {
      url = "github:LisaScheers/nix-honeypot";
      inputs = {
        flake-parts.follows = "flake-parts";
        import-tree.follows = "import-tree";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-output-monitor.url = "github:maralorn/nix-output-monitor";
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nixpkgs-atlas-apps.url = "github:NixOS/nixpkgs/master";
    nixpkgs-nook-apps.url = "github:NixOS/nixpkgs/master";
    nixvim.url = "github:nix-community/nixvim";
    onepassword-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    personal-website = {
      url = "github:LisaScheers/me";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pwndbg = {
      url = "github:pwndbg/pwndbg/2026.09.15";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    steam-asahi = {
      url = "github:sm-idk/steam-asahi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    t3-code-nix = {
      url = "github:LisaScheers/t3-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tstack = {
      url = "github:t3dotgg/tstack";
      flake = false;
    };
    zed.url = "github:zed-industries/zed";
  };
}
