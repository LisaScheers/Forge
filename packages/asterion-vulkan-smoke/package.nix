{
  lib,
  stdenv,
  pkg-config,
  vulkan-headers,
  vulkan-loader,
  glslang,
  python3,
  mesa,
  runCommand,
  coreutils,
  gnugrep,
  vulkan-validation-layers,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "asterion-vulkan-smoke";
  version = "1";
  src = ./.;
  nativeBuildInputs = [pkg-config glslang python3];
  buildInputs = [vulkan-headers vulkan-loader];
  strictDeps = true;
  buildPhase = ''
    runHook preBuild
    for shader in triangle.vert triangle.frag compute.comp; do
      glslangValidator -V --target-env vulkan1.0 "$shader" -o "$shader.spv"
    done
    python3 -B embed.py
    $CC -std=c11 -O2 -Wall -Wextra -Werror smoke.c -o asterion-vulkan-smoke \
      $(pkg-config --cflags --libs vulkan)
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 asterion-vulkan-smoke "$out/bin/asterion-vulkan-smoke"
    runHook postInstall
  '';
  passthru.tests.softwareOracle =
    runCommand "asterion-vulkan-smoke-software-oracle" {
      nativeBuildInputs = [coreutils gnugrep];
    } ''
      mkdir "$out"
      icds=(${mesa}/share/vulkan/icd.d/lvp_icd*.json)
      test ''${#icds[@]} = 1
      export VK_DRIVER_FILES="''${icds[0]}"
      export XDG_RUNTIME_DIR="$TMPDIR"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      mkdir -p "$XDG_CACHE_HOME"
      export VK_LAYER_PATH=${vulkan-validation-layers}/share/vulkan/explicit_layer.d
      export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
      timeout --kill-after=5s 30 ${finalAttrs.finalPackage}/bin/asterion-vulkan-smoke --allow-software \
        > "$out/oracle.log" 2>&1
      cat "$out/oracle.log"
      ! grep -E 'Validation Error|VUID-' "$out/oracle.log"
      if timeout --kill-after=5s 30 ${finalAttrs.finalPackage}/bin/asterion-vulkan-smoke \
        > "$out/refusal.log" 2>&1; then
        echo 'Default mode incorrectly accepted software Vulkan' >&2
        exit 1
      fi
      grep -F 'expected Apple M3 Pro (G15S); refusing another Vulkan device' "$out/refusal.log"
    '';
  meta = {
    description = "Headless M3 Pro Vulkan raster and compute readback check";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "asterion-vulkan-smoke";
  };
})
