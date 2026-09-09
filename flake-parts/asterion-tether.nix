{...}: {
  forge.modules.nixos.asterion-tether =
    # An installer entirely in RAM: m1n1 transfers it over USB, without a boot disk.
    {
      pkgs,
      lib,
      modulesPath,
      ...
    }: {
      imports = [
        (modulesPath + "/installer/netboot/netboot-base.nix")
        (modulesPath + "/profiles/minimal.nix")
      ];

      hardware.asahi = {
        enable = true;
        extractPeripheralFirmware = false;
        setupAsahiSound = false;
      };
      hardware.enableAllFirmware = lib.mkForce false;
      hardware.enableRedistributableFirmware = lib.mkForce false;
      boot.supportedFilesystems.zfs = false;
      # Firmware extraction runs during initrd activation. Unlike the ISO, the
      # RAM filesystem layout does not automatically pull in FAT charset modules.
      boot.initrd.kernelModules = ["vfat" "nls_cp437" "nls_iso8859-1"];
      boot.initrd.compressor = "gzip";
      boot.initrd.compressorArgs = ["-n" "-1"];
      netboot.squashfsCompression = "zstd -Xcompression-level 6";
      system.extraDependencies = lib.mkForce [];
      installer.cloneConfig = false;
      nixpkgs.flake.setNixPath = false;
      nixpkgs.flake.setFlakeRegistry = false;
      nix.settings.experimental-features = ["nix-command" "flakes"];
      networking.networkmanager.wifi.backend = "iwd";
      security.polkit.enable = lib.mkForce false;
      console.packages = [pkgs.terminus_font];
      console.font = "ter-v32n";
      system.stateVersion = "26.05";

      # Same firmware source as the upstream ISO. Mount only the ESP identified by
      # m1n1, read-only; proprietary firmware stays on the target, outside the build.
      boot.postBootCommands = ''
        (
          set -eu
          esp_uuid=$(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition)
          test -n "$esp_uuid"
          work=$(mktemp -d /run/asahi-firmware.XXXXXX)
          trap 'if mountpoint -q "$work/esp"; then umount "$work/esp"; fi; rm -rf "$work"' EXIT
          mkdir -p "$work/esp" "$work/extracted" "$work/unpacked"
          mount -t vfat -o ro,iocharset=iso8859-1 /dev/disk/by-partuuid/"$esp_uuid" "$work/esp"
          archive="$work/esp/vendorfw/firmware.cpio"
          if ! test -s "$archive"; then
            ${pkgs.asahi-fwextract}/bin/asahi-fwextract "$work/esp/asahi" "$work/extracted"
            archive="$work/extracted/firmware.cpio"
          fi
          cd "$work/unpacked"
          ${pkgs.cpio}/bin/cpio -id --quiet --no-absolute-filenames < "$archive"
          mkdir -p /lib/firmware
          cp -r vendorfw/. /lib/firmware/
          cd /
        )
      '';
    };
}
