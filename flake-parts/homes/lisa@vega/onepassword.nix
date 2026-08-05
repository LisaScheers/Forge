{pkgs, ...}: {
  programs._1password-shell-plugins = {
    enable = true;
    plugins = with pkgs; [awscli2 cachix];
    package = pkgs._1password-cli;
  };

  home.packages = [
    pkgs.gh
    #ghWith1Password disables due to anoying popups when running gh commands that require 1password auth, so we use the normal gh package instead
  ];
}
