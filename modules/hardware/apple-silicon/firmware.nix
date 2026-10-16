{
  overlays.asahi-firmware-j516s = final: _prev: {
    asahi-firmware-j516s = final.callPackage ../../../packages/asahi-firmware-j516s/asahi-firmware-j516s.pkg.nix {};
  };
  perSystem = {pkgs, ...}: {
    packages.asahi-firmware-j516s = pkgs.asahi-firmware-j516s;
  };
}
