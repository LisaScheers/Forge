{
  forge.modules.homeManager."lisa@vega" = {pkgs, ...}: {
    home.packages = with pkgs; [
      forgejo-cli
      tree
      pnpm
      nodejs_24
    ];
  };
}
