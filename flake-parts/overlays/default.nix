# --- flake-parts/overlays/default.nix
{inputs, ...}: let
  antigravity-cli = final: _prev: {
    antigravity-cli = inputs.antigravity-cli.packages.${final.stdenv.hostPlatform.system}.default;
  };

  codex = final: _prev: {
    codex = inputs.codex-cli-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };

  claudex = final: _prev: {
    claudex = final.callPackage ../_packages/claudex.nix {};
  };

  postplan-selfhosted = final: _prev: {
    postplan-selfhosted = final.callPackage ../_packages/postplan-selfhosted.nix {};
  };

  zed = final: _prev: {
    zed-editor = inputs.zed.packages.${final.stdenv.hostPlatform.system}.default.override {
      # Zed pins cargo-about to 0.8.2, which does not have the inherited `cli` feature.
      cargo-about = final.cargo-about.overrideAttrs (_old: {
        cargoBuildFeatures = [];
        cargoCheckFeatures = [];
      });
    };
  };

  # Nushell's integration tests assume a full TTY/shell nesting; they fail
  # on Darwin Nix builds with EPERM / wrong SHLVL (see env.rs SHLVL checks).
  nushell = _final: prev: {
    nushell =
      if prev.stdenv.hostPlatform.isDarwin
      then
        prev.nushell.overrideAttrs (_old: {
          doCheck = false;
        })
      else prev.nushell;
  };

  flake-parts-builder = final: prev: {
    flake-parts-builder = inputs.flake-parts-builder.packages.${final.stdenv.hostPlatform.system}.default;
  };

  default = final: prev:
    (antigravity-cli final prev)
    // (claudex final prev)
    // (codex final prev)
    // (postplan-selfhosted final prev)
    // (nushell final prev)
    // (flake-parts-builder final prev)
    // (zed final prev);
in {
  flake.overlays = {
    inherit antigravity-cli claudex codex default flake-parts-builder nushell postplan-selfhosted zed;
  };

  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [default];
      config.allowUnfree = true;
    };
  in {
    _module.args.pkgs = pkgs;
    packages.claudex = pkgs.claudex;
    packages.postplan-selfhosted = pkgs.postplan-selfhosted;
    packages.zed-editor = pkgs.zed-editor;
  };

  flake-file.inputs.antigravity-cli = {
    url = "github:selfhost-it/antigravity-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake-file.inputs.codex-cli-nix = {
    url = "github:sadjow/codex-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake-file.inputs.flake-parts-builder = {
    url = "github:tsandrini/flake-parts-builder";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
