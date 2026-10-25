{
  nixos.asterion-gpu = {
    config,
    lib,
    pkgs,
    ...
  }: let
    kernel = pkgs.callPackage ../../../packages/asterion-gpu-test-kernel/package.nix {};
    mesa = pkgs.callPackage ../../../packages/asterion-gpu-test-mesa/package.nix {};
    gpuModules = pkgs.callPackage ../../../packages/asterion-gpu-test-modules/package.nix {
      kernel = config.boot.kernelPackages.kernel;
    };
  in {
    boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);
    boot.extraModulePackages = [gpuModules];
    # Preserve the firmware console for the disk-unlock prompt. Native DRM and
    # the GPU are loaded explicitly by the readiness service after mounting root.
    boot.blacklistedKernelModules = ["appledrm" "asahi"];
    boot.supportedFilesystems.zfs = false;
    hardware.graphics = {
      enable = true;
      package = mesa;
    };
    systemd.services.asterion-gpu-ready = {
      description = "Prepare the M3 Pro GPU and native panel for the desktop";
      wantedBy = ["multi-user.target"];
      requiredBy = ["greetd.service"];
      before = ["greetd.service"];
      after = ["systemd-udev-trigger.service"];
      # A running compositor must survive configuration switches; new kernels
      # and their display preparation take effect on the next boot.
      restartIfChanged = false;
      path = with pkgs; [coreutils gnugrep kmod systemd];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 90;
      };
      script = ''
        set -eu
        tr '\0' '\n' < /proc/device-tree/compatible | grep -Fxq apple,j516s
        modprobe appledrm
        panel=/sys/class/backlight/apple-panel-bl
        for attempt in $(seq 1 300); do
          test ! -f "$panel/brightness" || break
          sleep .1
        done
        test -f "$panel/brightness"
        # Loading appledrm creates the panel and queues its brightness restore.
        # Finish that restore before requesting the level checked below.
        udevadm settle --timeout=20
        systemctl start systemd-backlight@backlight:apple-panel-bl.service
        if test -w /sys/class/graphics/fb0/blank; then
          echo 0 > /sys/class/graphics/fb0/blank
        fi
        echo 200 > "$panel/brightness"
        for attempt in $(seq 1 100); do
          actual=$(cat "$panel/actual_brightness" 2>/dev/null || true)
          test "$actual" != 200 || break
          sleep .1
        done
        if test "$(cat "$panel/actual_brightness")" != 200; then
          echo "Native panel brightness check failed: requested $(cat "$panel/brightness"), actual $(cat "$panel/actual_brightness"), expected 200 nits." >&2
          exit 1
        fi
        modprobe asahi
        for attempt in $(seq 1 100); do
          test ! -c /dev/dri/renderD128 || break
          sleep .1
        done
        test -c /dev/dri/renderD128
        udevadm settle --timeout=20
        echo 'Native M3 Pro render node and 200-nit panel ready.'
      '';
    };
  };
}
