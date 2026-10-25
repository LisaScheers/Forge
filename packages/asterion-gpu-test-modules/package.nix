{
  kernel,
  lib,
  kmod,
  ...
}:
kernel.stdenv.mkDerivation {
  pname = "asterion-gpu-test-modules";
  version = "${kernel.version}-qualified1-opaque1";
  src = kernel.src;
  patches = [
    ../asterion-gpu-test-kernel/g15-firmware-qualification.patch
    ../asterion-gpu-test-kernel/native-display-fix.patch
    ../asterion-gpu-test-kernel/j516s-opaque-x.patch
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies ++ [kmod];
  hardeningDisable = ["all"];
  dontStrip = true;
  dontPatchELF = true;
  buildPhase = ''
    runHook preBuild
    for driver in asahi apple; do
      make ${lib.escapeShellArgs (kernel.commonMakeFlags ++ ["-C" "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" "-j6"])} \
        M="$PWD/drivers/gpu/drm/$driver" modules
    done
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    for driver in asahi apple; do
      for module in drivers/gpu/drm/$driver/*.ko; do
        install -Dm644 "$module" "$out/lib/modules/${kernel.modDirVersion}/updates/$(basename "$module")"
        modinfo -F vermagic "$module" | grep -F '${kernel.modDirVersion} '
      done
    done
    test -f "$out/lib/modules/${kernel.modDirVersion}/updates/asahi.ko"
    test -f "$out/lib/modules/${kernel.modDirVersion}/updates/appledrm.ko"
    runHook postInstall
  '';
  passthru.testRevision = "g15-qualified1-panel-nits1-opaque1";
}
