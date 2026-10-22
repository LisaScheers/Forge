{inputs, ...}: {
  flake-file.inputs.nixvim.url = "github:nix-community/nixvim";

  perSystem = {
    system,
    pkgs,
    ...
  }: let
    editor = import ../../packages/nixvim/nixvim.pkg.nix {
      inherit system;
      inherit (inputs) nixvim;
      nixd = pkgs.nixd;
      nixdSettings = inputs.self.lib.nixdSettings pkgs;
      inherit (pkgs) oxfmt oxlint;
      dotnetSdk = pkgs.dotnetCorePackages.sdk_10_0;
      inherit (pkgs) roslyn-ls csharpier netcoredbg;
    };
  in {
    packages.nixvim = editor;
    checks.nixvim = editor.config.build.test;
  };

  home.lisa-cli = {pkgs, ...}: {
    home.packages = [inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixvim];
  };
}
