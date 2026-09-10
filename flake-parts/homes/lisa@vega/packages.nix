{
  forge.modules.homeManager."lisa@vega" = {pkgs, ...}: {
    home.packages = with pkgs; [
      tree
      pnpm
      nodejs_24
    ];
  };
}
