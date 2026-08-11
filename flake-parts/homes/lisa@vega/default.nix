{pkgs, ...}: {
  imports = [
    ./git.nix
    ./starship.nix
    ./direnv.nix
    ./packages.nix
    ./shells.nix
    ./ghostty.nix
    ./files.nix
    ./darwin.nix
    ./onepassword.nix
    ./ssh.nix
  ];
  home.username = "lisa";
  home.homeDirectory = "/Users/lisa";

  forge.codex.enable = true;

  home.stateVersion = "25.11";

  xdg.enable = true;

  programs.home-manager.enable = true;
  manual.manpages.enable = false;

  programs.zed-editor = import ./zed {inherit pkgs;};
}
