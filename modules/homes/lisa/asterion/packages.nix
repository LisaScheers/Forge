{
  home.lisa-asterion = {pkgs, ...}: {
    home.packages = with pkgs; [
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
      obsidian
    ];
    # Java 8's optional GTK theme pulls in the retired GTK2 package.
    xdg.dataFile."java/8".source = "${pkgs.zulu8.override {gtkSupport = false;}}";
  };
}
