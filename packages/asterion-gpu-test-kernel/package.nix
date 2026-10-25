{
  lib,
  buildLinux,
  fetchurl,
  runCommand,
  buildPackages,
  ...
} @ args: let
  revision = "b6f070c911934c9c377c4be939b883bf32f37acf";
  upstream = fetchurl {
    url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.11.tar.xz";
    hash = "sha256-/Q/EefmDqMBTE/E+nDYzD+ZlHPclOWdIxA1c2T+h5qQ=";
  };
  forkDiff = fetchurl {
    url = "https://github.com/omacom/linux-aurora/compare/a2de78ee6ed8bf8cd99d177c74865a6e8c3cb6ea...${revision}.diff";
    hash = "sha256-uoiGLN8skY1Qaz9z2N36eo9qM/eVpZdmWJVx/B1HRGc=";
  };
in
  buildLinux (lib.recursiveUpdate {
    pname = "asterion-gpu-test-linux";
    version = "7.2.11";
    modDirVersion = "7.2.11-asterion-gpu-test-pmp1";
    extraMeta.branch = "7.2";
    extraMakeFlags = ["-j8"];
    # NixOS overrides this package with its own patch list; keep the local fix.
    kernelPatches =
      [
        {
          name = "t6030-static-pmp";
          patch = ./t6030-static-pmp.patch;
        }
      ]
      ++ (args.kernelPatches or []);
    # GitHub refuses this large repository's archive. Reconstruct the same
    # immutable tree from the upstream release and an immutable compare diff.
    src =
      runCommand "asterion-gpu-test-kernel-source-${builtins.substring 0 12 revision}.tar.gz" {
        nativeBuildInputs = with buildPackages; [gitMinimal gnutar gzip xz];
      } ''
        mkdir source
        tar -xf ${upstream} --strip-components=1 -C source
        cd source
        export GIT_CONFIG_NOSYSTEM=1
        export GIT_CONFIG_GLOBAL=/dev/null
        git apply --binary ${forkDiff}
        git init --bare -q "$TMPDIR/source.git"
        git --git-dir="$TMPDIR/source.git" --work-tree="$PWD" \
          -c core.fileMode=true add --force --all
        kernel_tree=$(git --git-dir="$TMPDIR/source.git" --work-tree="$PWD" write-tree)
        test "$kernel_tree" = bcd567a2469cdd00bc2f88340f16f70412c8e68e
        # Keep case-distinct Linux paths inside an archive when this output is
        # copied through the macOS store before the Linux kernel build.
        cd ..
        tar --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner \
          -cf - source | gzip -n > "$out"
      '';
    structuredExtraConfig = with lib.kernel; {
      LOCALVERSION = freeform "-asterion-gpu-test-pmp1";
      ARM64_16K_PAGES = yes;
      ARM64_MEMORY_MODEL_CONTROL = yes;
      ARM64_ACTLR_STATE = yes;
      APPLE_WATCHDOG = yes;
      APPLE_M1_CPU_PMU = yes;
      APPLE_PMGR_MISC = yes;
      APPLE_PMGR_PWRSTATE = yes;
      APPLE_MAILBOX = yes;
      APPLE_RTKIT = yes;
      APPLE_PMP = yes;
      OF_DYNAMIC = yes;
      OF_OVERLAY = yes;
      APPLE_T6030_DISPLAY_GATE = yes;
      BACKLIGHT_CLASS_DEVICE = yes;
      DRM = yes;
      DRM_APPLE = module;
      DRM_ASAHI = module;
      DRM_ASAHI_G15 = yes;
      # The experiment has no reason to provision SEP keybags or touch xART.
      APPLE_SEP = no;
    };
    features.rust = true;
    extraPassthru.sourceRevision = revision;
    extraPassthru.testPatchRevision = "t6030-static-pmp-v1";
  } (removeAttrs args ["lib" "buildLinux" "fetchurl" "runCommand" "buildPackages" "kernelPatches"]))
