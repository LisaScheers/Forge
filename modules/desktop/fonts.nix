{inputs, ...}: {
  darwin.vega = {pkgs, ...}: let
    comicCodeNerdFont = pkgs.callPackage ../../packages/comic-code-nerd-font/package.nix {
      fontSource = inputs.comic-code-fonts;
    };
  in {
    fonts.packages = [
      comicCodeNerdFont
    ];
  };
  flake-file.inputs.comic-code-fonts = {
    url = "github:LisaScheers/comic-code-fonts";
    flake = false;
  };
}
