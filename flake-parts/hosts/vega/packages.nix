{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    just
    sops
    age
    ssh-to-age
    alejandra
    fh
    nil
    nixd
    ripgrep
    raycast
    ghostty-bin
    ghostty-bin.terminfo
    element-desktop
    #mpv
    obsidian
    orbstack
    slack
    the-unarchiver
    oxfmt
    oxlint
    flake-parts-builder
  ];
}
