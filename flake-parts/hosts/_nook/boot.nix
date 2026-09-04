{
  boot.initrd.systemd.enable = true;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    devices = ["/dev/disk/by-id/nvme-eui.002538ba71b63d8a"];
  };
}
