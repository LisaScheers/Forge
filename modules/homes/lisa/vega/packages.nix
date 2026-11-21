{
  home.lisa-vega = {pkgs, ...}: {
    xdg.dataFile."java/8".source = "${pkgs.zulu8}";
  };
}
