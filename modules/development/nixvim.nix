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
    checks.nixvim-tutorial = pkgs.runCommand "nixvim-tutorial-check" {} ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"
      mkdir -p "$HOME"
      ${editor}/bin/nvim --headless '+luafile ${../../packages/nixvim/tests/tutorial.lua}' > tutorial.log 2>&1 || {
        cat tutorial.log
        exit 1
      }
      cat tutorial.log
      touch "$out"
    '';
  };

  home.lisa-cli = {pkgs, ...}: {
    home.packages = [inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixvim];
  };
}
