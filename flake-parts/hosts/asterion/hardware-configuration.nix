{
  forge.modules.nixos.asterion = {
    nixpkgs.hostPlatform = "aarch64-linux";

    # These labels are assigned only to Asterion's new root and Asahi ESP.
    boot.initrd.luks.devices.asterion-root.device = "/dev/disk/by-partlabel/asterion-root";
    # The built-in input devices must be available for the LUKS prompt.
    boot.initrd.extraFirmwarePaths = ["apple/*"];
    fileSystems."/" = {
      device = "/dev/disk/by-label/asterion";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-label/ASTERIONEFI";
      fsType = "vfat";
      options = ["umask=0077"];
    };
  };
}
