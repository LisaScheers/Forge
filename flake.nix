# This flake.nix file is auto-generated.
# The source of truth is merged from flake-parts modules under flake-parts/.
# Regenerate with: nix run .#write-flake
# https://flake-file.denful.dev/
{
  description = "Multi-host Nix configuration for Darwin and NixOS";

  outputs = inputs: import ./outputs.nix inputs;

  nixConfig = {
    extra-substituters = [
      "https://zed.cachix.org"
      "https://zed.cachix.org"
    ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
    ];
    extraSubstituters = [ ];
    extraTrustedPublicKeys = [ ];
  };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-cli = {
      url = "github:selfhost-it/antigravity-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      url = "github:serokell/deploy-rs/c03082a563c010c03a5c3d5e1507ccd9dd53d341";
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
    flake-parts-builder = {
      url = "github:tsandrini/flake-parts-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:LisaScheers/home-manager/agent/nushell-session-environment";
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
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs = {
        lix.follows = "lix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-auto-follow = {
      url = "github:fzakaria/nix-auto-follow";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    onepassword-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pony-tack = {
      url = "git+ssh://git@ssh.github.com:443/LisaScheers/sl-pony-tack.git?ref=main";
      flake = false;
    };
    shop-empty-track = {
      url = "github:LisaScheers/shop-empty-track/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sl-remote = {
      url = "github:LisaScheers/sl-remote/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    t3-code-nix = {
      url = "github:LisaScheers/t3-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zed = {
      url = "github:zed-industries/zed";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
