{config, ...}: {
  # What Lisa's workstation homes (Vega and Asterion) share beyond home.lisa.
  # Each still names its own 1Password signer and Java 8 build.
  home.workstation = {pkgs, ...}: {
    imports = [config.home.chrome-tab config.home.ssh-public-keys config.home.onepassword];
    xdg.enable = true;
    programs.home-manager.enable = true;
    home.sessionVariables.FJ_FALLBACK_HOST = "https://git.bylisa.dev";
    home.packages = with pkgs; [
      forgejo-cli
      tree
      pnpm
      nodejs_24
    ];
    xdg.dataFile = {
      "java/17".source = "${pkgs.jdk17}";
      "java/21".source = "${pkgs.jdk21}";
      "java/25".source = "${pkgs.jdk25}";
    };
  };
}
