{
  forge.modules.homeManager."lisa@vega" = {pkgs, ...}: {
    home.sessionVariables.FJ_FALLBACK_HOST = "https://git.bylisa.dev";
    home.packages = with pkgs; [
      forgejo-cli
      tree
      pnpm
      nodejs_24
    ];
  };
}
