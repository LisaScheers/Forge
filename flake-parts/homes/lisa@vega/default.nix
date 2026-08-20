{lib, ...}: let
  dir = ./programs;
  entries = builtins.readDir dir;
  modules =
    map (name: dir + "/${name}")
    (lib.filter
      (name:
        entries.${name}
        == "regular"
        && lib.hasSuffix ".nix" name)
      (builtins.attrNames entries));
in {
  imports =
    [
      ../lisa
      ./packages.nix
      ./files.nix
    ]
    ++ modules;
  home.username = "lisa";
  home.homeDirectory = "/Users/lisa";

  xdg.enable = true;

  programs.home-manager.enable = true;
  manual.manpages.enable = false;
}
