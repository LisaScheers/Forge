{
  nixos.asterion-gpu-boot = {
    config,
    pkgs,
    lib,
    ...
  }: let
    kernel = config.boot.kernelPackages.kernel;
    m1n1 = pkgs.callPackage ../../../packages/asterion-gpu-test-m1n1/package.nix {
      m1n1 = pkgs.m1n1;
    };
    dtb = pkgs.callPackage ../../../packages/asterion-gpu-test-dtb/package.nix {inherit kernel;};
    uboot = config.hardware.asahi.pkgs.uboot-asahi.override {inherit m1n1;};
    bootOptions = pkgs.writeText "asterion-gpu-m1n1-options" (config.boot.m1n1ExtraOptions + "\n");
    bootImage =
      pkgs.runCommand "asterion-gpu-boot.bin" {
        nativeBuildInputs = [pkgs.gzip pkgs.gawk];
        passthru = {inherit m1n1 dtb uboot bootOptions;};
      } ''
        set -eu
        for expected in \
          'chosen.asahi,t6030-dcp=1' \
          'chosen.asahi,t6030-gpu=1' \
          'chosen.asahi,efi-system-partition=6b247b53-374b-4729-ba44-9b93de5aba90'; do
          grep -Fxq "$expected" ${bootOptions}
          key=''${expected%%=*}
          test "$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' ${bootOptions})" = 1
        done
        grep -aFq '##m1n1_ver##asterion-gpu-test-f5a82fdb6264' ${m1n1}/lib/m1n1/m1n1.bin
        gzip -t ${uboot}/u-boot-nodtb.bin.gz
        cat ${m1n1}/lib/m1n1/m1n1.bin \
          ${dtb}/t6030-j516s.dtb \
          ${uboot}/u-boot-nodtb.bin.gz \
          ${bootOptions} > "$out"
        test -s "$out"
      '';
  in {
    boot.m1n1ExtraOptions = ''
      chosen.asahi,t6030-dcp=1
      chosen.asahi,t6030-gpu=1
      chosen.asahi,efi-system-partition=6b247b53-374b-4729-ba44-9b93de5aba90
    '';
    # Keep the DTB that m1n1 populated with this boot's firmware handoff.
    boot.loader.systemd-boot.installDeviceTree = lib.mkForce false;
    hardware.deviceTree.name = lib.mkForce null;
    boot.loader.grub.extraFiles."m1n1/boot.bin" = lib.mkForce bootImage;
    boot.loader.systemd-boot.extraFiles."m1n1/boot.bin" = lib.mkForce bootImage;
    boot.loader.limine.additionalFiles."m1n1/boot.bin" = lib.mkForce bootImage;
    system.build.m1n1 = lib.mkForce bootImage;
    system.extraDependencies = lib.mkOverride 40 [m1n1 uboot];
  };
}
