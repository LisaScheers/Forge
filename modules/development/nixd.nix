{inputs, ...}: {
  # Shared by the nixd config file, Nixvim and Zed.
  flake.lib.nixdSettings = pkgs: let
    # The checkout each host edits Forge in. Unlike Forge's own store copy, a
    # path string keeps the repository out of every closure, so unrelated edits
    # leave editor configs unchanged and pull request CI can skip their builds.
    checkout =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "/Users/lisa/Projects/Scheers/forge"
      else "/etc/nixos/forge";
    flake = "(builtins.getFlake ${builtins.toJSON checkout})";
    homeName =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "lisa@vega"
      else if pkgs.stdenv.hostPlatform.isAarch64
      then "lisa@asterion"
      else "lisa@nook";
  in {
    nixpkgs.expr = "import <nixpkgs> { }";
    # Match checks.lint so format-on-save never fights the repository style.
    formatting.command = ["${pkgs.lib.getExe pkgs.alejandra}"];
    options = {
      nixos.expr = "${flake}.nixosConfigurations.atlas.options";
      darwin.expr = "${flake}.darwinConfigurations.vega.options";
      home-manager.expr = "${flake}.homeConfigurations.${builtins.toJSON homeName}.options";
      flake-parts.expr = "${flake}.debug.options";
      flake-file.expr = "${flake}.debug.options.flake-file.type.getSubOptions []";
      devenv.expr = "{ devenv.shells.default = ${flake}.allSystems.${builtins.toJSON pkgs.stdenv.hostPlatform.system}.options.devenv.shells.type.getSubOptions []; }";
    };
  };

  perSystem = {pkgs, ...}: {
    packages.nixd-config =
      (pkgs.formats.json {}).generate "nixd-config.json"
      (inputs.self.lib.nixdSettings pkgs);
  };

  home.lisa = {pkgs, ...}: {
    home.packages = [pkgs.nixd];
    xdg.configFile."nixd/config.json".source =
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixd-config;
  };
}
