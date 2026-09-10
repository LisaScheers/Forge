{
  forge.modules.homeManager."lisa" = {pkgs, ...}: {
    home.packages = [
      pkgs.devenv
    ];
  };
}
