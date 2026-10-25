{
  home.lisa-asterion = {
    pkgs,
    osConfig ? null,
    ...
  }: let
    mesa =
      if osConfig != null
      then osConfig.hardware.graphics.package
      else pkgs.callPackage ../../../packages/asterion-gpu-test-mesa/package.nix {};
    session = pkgs.callPackage ../../../packages/asterion-gpu-session/package.nix {
      inherit mesa;
      installed = true;
    };
  in {
    xdg.configFile = {
      "niri/config.kdl".source = session.config;
      "foot/foot.ini".source = session.footConfig;
    };

    home.packages = with pkgs; [
      session
      wl-clipboard
      wireplumber
      pavucontrol
      networkmanagerapplet
      nautilus
    ];
    home.sessionVariables.NIXOS_OZONE_WL = "1";
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    programs.swaylock.enable = false;
    catppuccin.swaylock.enable = false;
    services.swayidle.enable = false;
    services.polkit-gnome.enable = true;
  };
}
