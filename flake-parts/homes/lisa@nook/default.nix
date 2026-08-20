{...}: let
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
  imports = [../lisa] ++ modules;
  home.homeDirectory = "/home/lisa";
}
