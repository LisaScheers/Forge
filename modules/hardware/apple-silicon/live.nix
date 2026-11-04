{
  config,
  inputs,
  ...
}: let
  flakeConfig = config;
  live = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      config.nixos.asterion-installer-common
      config.nixos.asterion-tether
      config.nixos.asterion-live
    ];
  };
  inherit (live) pkgs;
  kernel = live.config.boot.kernelPackages.kernel;
  mesa = live.config.hardware.graphics.package;
  gpuModules = pkgs.callPackage ../../../packages/asterion-gpu-modules/package.nix {inherit kernel;};
  dtb = pkgs.callPackage ../../../packages/asterion-gpu-dtb/package.nix {inherit kernel;};
  vulkanSmoke = pkgs.callPackage ../../../packages/asterion-vulkan-smoke/package.nix {};
  gpuSession = pkgs.callPackage ../../../packages/asterion-gpu-session/package.nix {inherit mesa;};
  m1n1 = pkgs.callPackage ../../../packages/asterion-gpu-m1n1/package.nix {};
  manifest = pkgs.writeText "asterion-live-manifest.json" (builtins.toJSON {
    kind = "asterion-live";
    target = "J516s";
    kernelRevision = kernel.sourceRevision;
    kernelPatch = kernel.integrationRevision;
    dtbCompatibilityPatch = "g15-uat-reservation-names-v1";
    modulePatch = gpuModules.integrationRevision;
    mesaRevision = mesa.sourceRevision;
    m1n1Revision = m1n1.sourceRevision;
    privateWifiSupport = true;
    privateSshSupport = true;
  });
in {
  nixos.asterion-live = {
    config,
    pkgs,
    lib,
    ...
  }: let
    kernel = pkgs.callPackage ../../../packages/asterion-gpu-kernel/package.nix {};
    mesa = pkgs.callPackage ../../../packages/mesa-aurora/package.nix {};
    smoke = pkgs.callPackage ../../../packages/asterion-gpu-smoke/package.nix {};
    gpuModules = pkgs.callPackage ../../../packages/asterion-gpu-modules/package.nix {
      kernel = config.boot.kernelPackages.kernel;
    };
    vulkanSmoke = pkgs.callPackage ../../../packages/asterion-vulkan-smoke/package.nix {};
    gpuSession = pkgs.callPackage ../../../packages/asterion-gpu-session/package.nix {inherit mesa;};
    check = pkgs.writeShellApplication {
      name = "asterion-gpu-check";
      runtimeInputs = with pkgs; [coreutils gnugrep kmod systemd util-linux vulkan-tools smoke vulkanSmoke];
      text = ''
        if [[ $# != 1 || $1 != --run ]]; then
          echo 'Usage: sudo asterion-gpu-check --run'
          echo 'Loads the experimental GPU and checks shader rendering and compute.'
          exit 2
        fi
        [[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
        tr '\0' '\n' < /proc/device-tree/compatible | grep -Fxq apple,j516s
        grep -qw asterion.live=1 /proc/cmdline
        [[ $(findmnt -n -o FSTYPE /) == tmpfs ]]
        if findmnt --evaluate -rn -o SOURCE,OPTIONS | grep -E '^/dev/[^ ]+ .*\brw\b'; then
          echo 'Refusing a RAM GPU check with a block device mounted writable.' >&2
          exit 1
        fi
        results=$(mktemp -d /run/asterion-live.XXXXXX)
        echo "Results: $results"
        exec > >(tee "$results/check.log") 2>&1
        trap 'journalctl -b -k --no-pager > "$results/kernel.log"; ls -l /dev/dri > "$results/dri.txt" 2>&1 || true; cat /sys/kernel/debug/devices_deferred > "$results/deferred.txt" 2>&1 || true' EXIT
        uname -a
        cat /etc/asterion-live.json
        modprobe asahi
        udevadm settle --timeout=20
        render_nodes=(/dev/dri/renderD*)
        if [[ ! -e ''${render_nodes[0]} ]]; then
          echo 'FAIL: the GPU driver did not create a render node.' >&2
          cat /sys/kernel/debug/devices_deferred || true
          exit 1
        fi
        export __EGL_VENDOR_LIBRARY_FILENAMES=${mesa}/share/glvnd/egl_vendor.d/50_mesa.json
        export LIBGL_DRIVERS_PATH=${mesa}/lib/dri
        unset LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER MESA_LOADER_DRIVER_OVERRIDE
        timeout --kill-after=5s 60 asterion-gpu-smoke
        icds=(${mesa}/share/vulkan/icd.d/asahi_icd*.json)
        [[ ''${#icds[@]} == 1 && -f ''${icds[0]} ]]
        export VK_DRIVER_FILES="''${icds[0]}"
        timeout --kill-after=5s 30 vulkaninfo --summary > "$results/vulkan.txt" 2>&1
        cat "$results/vulkan.txt"
        timeout --kill-after=5s 60 asterion-vulkan-smoke > "$results/vulkan-smoke.txt" 2>&1
        cat "$results/vulkan-smoke.txt"
        echo 'PASS: checked native GLES and Vulkan graphics and compute.'
      '';
    };
  in {
    imports = [flakeConfig.nixos.asterion-gpu flakeConfig.nixos.asterion-audio];
    networking.hostName = lib.mkForce "asterion-live";
    boot.kernelParams = ["asterion.live=1" "log_buf_len=8M" "panic=10" "oops=panic"];
    boot.initrd.systemd = {
      services.asterion-private-wifi = {
        description = "Copy private Wi-Fi profiles into the RAM root";
        wantedBy = ["initrd.target"];
        after = ["sysroot.mount"];
        requires = ["sysroot.mount"];
        before = ["initrd-switch-root.target"];
        unitConfig.DefaultDependencies = false;
        unitConfig.ConditionPathExists = "/asterion-wifi.nmconnection";
        serviceConfig.Type = "oneshot";
        serviceConfig.ExecStart = [
          "${pkgs.coreutils}/bin/install -Dm600 /asterion-wifi.nmconnection /sysroot/etc/NetworkManager/system-connections/asterion-wifi.nmconnection"
          "${pkgs.coreutils}/bin/install -Dm600 /asterion-wifi.psk '/sysroot/var/lib/iwd/Lisa IOT.psk'"
        ];
      };
      services.asterion-private-ssh = {
        description = "Copy the private SSH public key into the RAM root";
        wantedBy = ["initrd.target"];
        after = ["sysroot.mount"];
        requires = ["sysroot.mount"];
        before = ["initrd-switch-root.target"];
        unitConfig.DefaultDependencies = false;
        unitConfig.ConditionPathExists = "/asterion-authorized-key";
        serviceConfig.Type = "oneshot";
        serviceConfig.ExecStart = [
          "${pkgs.coreutils}/bin/install -dm700 /sysroot/root/.ssh"
          "${pkgs.coreutils}/bin/install -m600 /asterion-authorized-key /sysroot/root/.ssh/authorized_keys"
        ];
      };
    };
    networking.networkmanager.settings.device."wifi.iwd.autoconnect" = false;
    swapDevices = lib.mkForce [];
    services.udisks2.enable = false;
    time.timeZone = "Europe/Brussels";
    # The installer disables polkit; the local desktop needs seat actions.
    security.polkit.enable = lib.mkOverride 40 true;
    services.dbus.enable = true;
    services.upower.enable = true;
    systemd.defaultUnit = "graphical.target";
    hardware.asahi.avd.enable = lib.mkForce false;
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          user = "nixos";
          command = "${gpuSession}/bin/asterion-gpu-session";
        };
        default_session = {
          user = "greeter";
          command = "${pkgs.greetd}/bin/agreety --cmd ${gpuSession}/bin/asterion-gpu-session";
        };
      };
    };
    services.openssh.settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
    users.users.root.openssh.authorizedKeys.keyFiles = [../../security/ssh/vega/public-keys/dev.pub];
    environment.systemPackages = [check smoke vulkanSmoke gpuSession pkgs.mesa-demos pkgs.vulkan-tools];
    environment.etc."asterion-live.json".text = builtins.toJSON {
      inherit (kernel) sourceRevision;
      kernelPatch = kernel.integrationRevision;
      modulePatch = gpuModules.integrationRevision;
      mesaRevision = mesa.sourceRevision;
      target = "J516s";
      purpose = "Asterion live RAM desktop and installer";
    };
  };

  flake.packages.aarch64-linux.asterion-live =
    pkgs.runCommand "asterion-live" {
      __structuredAttrs = true;
      nativeBuildInputs = [pkgs.gzip pkgs.dtc pkgs.squashfs-tools pkgs.kmod];
      # The initrd embeds the closure; bootargs must not retain a second copy.
      unsafeDiscardReferences.out = true;
    } ''
      set -o pipefail
      mkdir -p "$out"
      gzip -n -1 -c ${kernel}/${live.config.system.boot.loader.kernelFile} > "$out/Image.gz"
      cp ${dtb}/t6030-j516s.dtb "$out/t6030-j516s.dtb"
      cp ${m1n1}/lib/m1n1/m1n1.bin "$out/m1n1.bin"
      gzip -dc ${live.config.system.build.netbootRamdisk}/initrd | gzip -n -1 > "$out/initrd.gz"
      gzip -t "$out/Image.gz" "$out/initrd.gz"
      fdtget -t s "$out/t6030-j516s.dtb" / compatible | grep -qw apple,j516s
      # The display gate installs the admitted PMP overlay at boot.
      if fdtget -l "$out/t6030-j516s.dtb" /soc | grep -Eq '^(pmp_report@3503c0000|pmp@350500000)$'; then
        echo 'Unexpected static PMP in the upstream overlay profile.' >&2
        exit 1
      fi
      for region in uat-ttbs uat-pagetables uat-handoff uat-pagetables-l2; do
        test "$(fdtget -t s "$out/t6030-j516s.dtb" "/reserved-memory/$region" status)" = disabled
      done
      for module in asahi appledrm; do
        selected=$(modinfo -b ${live.config.system.modulesTree} -k ${kernel.modDirVersion} -n "$module")
        case "$selected" in
          */updates/"$module".ko*) ;;
          *) echo "Wrong module selected: $selected" >&2; exit 1 ;;
        esac
      done
      # linux.py reserves 512 MiB for the decompressed kernel in the 3 GiB heap.
      test $(( $(stat -c %s "$out/initrd.gz") + 512 * 1024 * 1024 + 16 * 1024 * 1024 )) -lt $((3 * 1024 * 1024 * 1024))
      unsquashfs -ll -no-progress ${live.config.system.build.squashfsStore} \
        ${builtins.baseNameOf live.config.system.build.toplevel}/init \
        | grep -F '/${builtins.baseNameOf live.config.system.build.toplevel}/init'
      echo 'init=${live.config.system.build.toplevel}/init ${toString live.config.boot.kernelParams}' > "$out/bootargs"
      cp ${manifest} "$out/manifest.json"
      cd "$out"
      sha256sum Image.gz t6030-j516s.dtb initrd.gz m1n1.bin bootargs manifest.json > SHA256SUMS
    '';

  flake.packages.aarch64-linux.asterion-gpu-modules = gpuModules;
  flake.packages.aarch64-linux.asterion-live-system = live.config.system.build.toplevel;
  flake.packages.aarch64-linux.asterion-vulkan-smoke = vulkanSmoke;
  flake.packages.aarch64-linux.asterion-gpu-session = gpuSession;
  flake.checks.aarch64-linux.asterion-vulkan-smoke = vulkanSmoke.tests.softwareOracle;

  flake.checks.aarch64-linux.asterion-gpu-command =
    pkgs.lib.findFirst
    (package: package.name == "asterion-gpu-check")
    (throw "Missing GPU validation command")
    live.config.environment.systemPackages;

  perSystem = {
    config,
    pkgs,
    ...
  }: let
    m1n1 = pkgs.callPackage ../../../packages/asterion-gpu-m1n1/package.nix {};
    proxySource = pkgs.runCommand "m1n1-asterion-gpu-proxyclient" {} ''
      cp -r ${m1n1.src} "$out"
      chmod -R u+w "$out"
      substituteInPlace "$out/proxyclient/m1n1/setup.py" \
        --replace-fail 'u = ProxyUtils(p)' 'u = ProxyUtils(p, heap_size=3 * 1024 * 1024 * 1024)'
    '';
  in {
    checks.asterion-tether-payload =
      pkgs.runCommand "asterion-tether-payload-checks" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        ASTERION_TETHER_LOADER=${../../../scripts/asterion-tether-boot.py} \
          python3 -B ${../../../scripts/test_asterion_tether_boot.py}
        ASTERION_PRIVATE_WIFI=${../../../scripts/asterion-private-wifi.py} \
          python3 -B ${../../../scripts/test_asterion_private_wifi.py}
        touch "$out"
      '';
    devShells.asahi-gpu-tether = config.devShells.asahi-tether.overrideAttrs {
      M1N1_SOURCE = toString proxySource;
      M1N1_SOURCE_REV = m1n1.sourceRevision;
    };
  };
}
