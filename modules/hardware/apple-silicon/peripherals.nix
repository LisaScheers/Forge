{
  nixos.asterion = {pkgs, ...}: {
    hardware.firmware = [
      (pkgs.callPackage ../../../packages/asterion-factory-calibration/package.nix {})
    ];
    hardware.asahi.avd = {
      enable = true;
      vaapi-support = true;
    };
    environment.systemPackages = [pkgs.libva-utils pkgs.v4l-utils];
  };
}
