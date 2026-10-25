{
  lib,
  stdenv,
  pkg-config,
  libglvnd,
}:
stdenv.mkDerivation {
  pname = "asterion-gpu-smoke";
  version = "1";
  src = ./.;
  nativeBuildInputs = [pkg-config];
  buildInputs = [libglvnd];
  strictDeps = true;
  buildPhase = ''
    runHook preBuild
    $CC -std=c11 -O2 -Wall -Wextra -Werror smoke.c -o asterion-gpu-smoke \
      $(pkg-config --cflags --libs egl glesv2)
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 asterion-gpu-smoke "$out/bin/asterion-gpu-smoke"
    runHook postInstall
  '';
  meta = {
    description = "Headless M3 Pro GLES graphics and compute readback check";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "asterion-gpu-smoke";
  };
}
