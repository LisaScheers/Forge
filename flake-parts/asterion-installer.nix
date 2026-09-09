{inputs, ...}: let
  common = {pkgs, ...}: {
    nixpkgs.hostPlatform = "aarch64-linux";
    nixpkgs.buildPlatform = "aarch64-linux";
    # nixpkgs' 0.8.0 parser rejects newer Apple Wi-Fi firmware filenames.
    # Keep this override local to the installers; firmware stays on the Mac.
    nixpkgs.overlays = [
      (final: prev: {
        asahi-fwextract = prev.asahi-fwextract.overrideAttrs {
          version = "0.8.0-unstable-2026-09-01";
          src = final.fetchFromGitHub {
            owner = "AsahiLinux";
            repo = "asahi-installer";
            rev = "99dff2e968dafcabc2a940865b051e91ffcfafd3";
            hash = "sha256-IbGH5pn65XL7tIbvwYLk1GLjjnp7wI1DV/4e94cySCc=";
          };
        };
      })
    ];
    networking.hostName = "asterion-installer";
    environment.systemPackages = with pkgs; [git cryptsetup gptfdisk dosfstools parted asahi-fwextract];
    systemd.sleep.settings.Sleep.AllowSuspend = false;
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
  installer = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-installer
      common
    ];
  };
  tether = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      common
      ./_asterion-tether.nix
    ];
  };
  inherit (tether) pkgs;
in {
  flake.packages.aarch64-linux.asterion-installer = installer.config.system.build.isoImage;
  flake.packages.aarch64-linux.asterion-tethered-installer =
    pkgs.runCommand "asterion-tethered-installer" {
      nativeBuildInputs = [pkgs.gzip];
    } ''
      set -o pipefail
      mkdir -p "$out"
      gzip -n -1 -c ${tether.config.system.build.kernel}/${tether.config.system.boot.loader.kernelFile} > "$out/Image.gz"
      cp ${tether.config.system.build.kernel}/dtbs/apple/t6030-j516s.dtb "$out/t6030-j516s.dtb"
      cp ${pkgs.m1n1}/lib/m1n1/m1n1.bin "$out/m1n1.bin"
      # Collapse the netboot initrd's gzip members into one stream for m1n1.
      gzip -dc ${tether.config.system.build.netbootRamdisk}/initrd | gzip -n -1 > "$out/initrd.gz"
      echo 'init=${tether.config.system.build.toplevel}/init ${toString tether.config.boot.kernelParams}' > "$out/bootargs"
    '';

  perSystem = {pkgs, ...}: let
    python = pkgs.python3.withPackages (p: [p.construct p.pyserial]);
    proxySource = pkgs.runCommand "m1n1-asterion-proxyclient" {} ''
      cp -r ${inputs.nixpkgs.legacyPackages.aarch64-linux.m1n1.src} "$out"
      chmod -R u+w "$out"
      # linux.py reserves 512 MiB for the kernel in addition to the full RAM
      # installer. Its default 1 GiB proxy heap is too small for both.
      substituteInPlace "$out/proxyclient/m1n1/setup.py" \
        --replace-fail 'u = ProxyUtils(p)' 'u = ProxyUtils(p, heap_size=2 * 1024 * 1024 * 1024)'
    '';
    llvm = pkgs.symlinkJoin {
      name = "asahi-proxy-llvm";
      paths = [pkgs.llvmPackages.clang-unwrapped pkgs.llvmPackages.llvm pkgs.llvmPackages.lld];
    };
  in {
    devShells.asahi-tether = pkgs.mkShellNoCC {
      packages = [python llvm pkgs.picocom];
      # Match the proxy client to the m1n1 binary in the Linux payload.
      M1N1_SOURCE = toString proxySource;
      USE_CLANG = "1";
      ARCH = "aarch64-none-elf";
      TOOLCHAIN = "${llvm}/bin/";
      LLDDIR = "${pkgs.llvmPackages.lld}/bin/";
      PYTHONDONTWRITEBYTECODE = "1";
    };
  };
}
