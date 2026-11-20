{
  home.lisa-vega = {pkgs, ...}: {
    home.sessionVariables.FJ_FALLBACK_HOST = "https://git.bylisa.dev";
    home.packages = with pkgs; [
      forgejo-cli
      tree
      pnpm
      nodejs_24
    ];

    xdg.dataFile = {
      "java/8".source = "${pkgs.zulu8}";
      "java/17".source = "${pkgs.jdk17}";
      "java/21".source = "${pkgs.jdk21}";
      "java/25".source = "${pkgs.jdk25}";
    };
  };
}
