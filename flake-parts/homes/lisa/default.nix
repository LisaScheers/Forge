{
  forge.modules.homeManager."lisa" = {pkgs, ...}: let
    inherit (pkgs.stdenv.hostPlatform) isDarwin;
  in {
    home.homeDirectory =
      if isDarwin
      then "/Users/lisa"
      else "/home/lisa";
    home.username = "lisa";
    home.stateVersion = "25.11";
  };
}
