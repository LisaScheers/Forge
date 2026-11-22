{inputs, ...}: let
  comicCodeNerdFont = pkgs:
    pkgs.callPackage ../../packages/comic-code-nerd-font/package.nix {
      fontSource = inputs.comic-code-fonts;
    };
in {
  darwin.vega = {pkgs, ...}: {
    fonts.packages = [(comicCodeNerdFont pkgs)];
  };
  home.lisa-asterion = {pkgs, ...}: {
    fonts.fontconfig.enable = true;
    home.packages = [(comicCodeNerdFont pkgs)];
  };
  flake-file.inputs.comic-code-fonts = {
    url = "github:LisaScheers/comic-code-fonts";
    flake = false;
  };
}
