{
  home.lisa-asterion = {pkgs, ...}: {
    home.packages = [pkgs.obsidian];
    # Java 8's optional GTK theme pulls in the retired GTK2 package.
    xdg.dataFile."java/8".source = "${pkgs.zulu8.override {gtkSupport = false;}}";
  };
}
