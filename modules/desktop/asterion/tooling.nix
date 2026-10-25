{
  config,
  inputs,
  ...
}: {
  home.lisa-asterion = {
    lib,
    pkgs,
    ...
  }: let
    comicCodeNerdFont = pkgs.callPackage ../../../packages/asterion-comic-code-font/package.nix {
      fontSource = inputs.comic-code-fonts;
    };
    zed = pkgs.callPackage ../../../packages/asterion-zed-bin/package.nix {};
  in {
    imports = [config.home.chrome-tab config.home.spotaui];

    programs.zed-editor = {
      enable = lib.mkForce true;
      package = zed;
      userSettings = {
        auto_update = false;
        terminal.env.TERM = lib.mkForce "xterm-ghostty";
      };
    };
    programs.ghostty = {
      enable = lib.mkForce true;
      package = lib.mkForce pkgs.ghostty;
    };
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      comicCodeNerdFont
      just
      sops
      age
      ssh-to-age
      alejandra
      fh
      nil
      nixd
      ripgrep
      oxfmt
      oxlint
      forgejo-cli
      tree
      pnpm
      nodejs_24
      element-desktop
      obsidian
    ];
    home.sessionVariables = {
      FJ_FALLBACK_HOST = "https://git.bylisa.dev";
      EDITOR = lib.mkForce "${lib.getExe zed} --wait";
      VISUAL = lib.mkForce "${lib.getExe zed} --wait";
    };
    xdg.dataFile = {
      "java/8".source = "${pkgs.zulu8}";
      "java/17".source = "${pkgs.jdk17}";
      "java/21".source = "${pkgs.jdk21}";
      "java/25".source = "${pkgs.jdk25}";
    };
  };
}
