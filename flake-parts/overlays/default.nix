# --- flake-parts/overlays/default.nix
{inputs, ...}: let
  codex = final: _prev: {
    codex = inputs.codex-cli-nix.packages.${final.stdenv.hostPlatform.system}.default;
  };

  claudex = final: _prev: {
    claudex = final.callPackage ../_packages/claudex.nix {};
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

  default = final: prev: (claudex final prev) // (codex final prev) // (nushell final prev) // (flake-parts-builder final prev);
in {
  flake.overlays = {
    inherit claudex codex default nushell flake-parts-builder;
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
