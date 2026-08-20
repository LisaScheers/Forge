{
  lib,
  system,
  ...
}: let
  isDarwin = (lib.systems.elaborate system).isDarwin;

  dir = ./programs;
  entries = builtins.readDir dir;
  modules =
    map (name: dir + "/${name}")
    (lib.filter
      (name:
        entries.${name}
        == "regular"
        && lib.hasSuffix ".nix" name)
      (builtins.attrNames entries))
    ++ lib.optional isDarwin ./darwin.nix;
in {
  imports = modules;
  home.homeDirectory =
    if isDarwin
    then "/Users/lisa"
    else "/home/lisa";
  home.username = "lisa";
  home.stateVersion = "25.11";
}
