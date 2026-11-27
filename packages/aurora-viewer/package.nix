{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  aws-lc,
  python3,
  apple-sdk_15,
}:
rustPlatform.buildRustPackage {
  pname = "aurora-viewer";
  version = "0.9.13";

  src = fetchFromGitHub {
    owner = "Aurora-Viewer";
    repo = "Aurora-Viewer";
    rev = "e961b7df61c49552773f3bc209d7d80d92a0b16b";
    hash = "sha256-7BcnNxGE/q2G9+kHjGFPWiRuLcUIVQcVL/4CmvWULuU=";
  };

  cargoHash = "sha256-DDUriOujYKHl9pyyxKvZ70qFcvwjLP7KN5+RoBlyqXM=";

  # macOS's Metal compiler fails to encode the fully inlined terrain shaders
  # on M3 and later (Aurora-Viewer#4785): a black world. Keep the debug views
  # in a function that the patched wgpu-hal leaves as a call. control.patch
  # adds the local control bridge behind AURORA_CONTROL_DIR (docs/aurora-viewer.md).
  # journal-texture-staging.patch stages texture uploads in the reused journal
  # staging buffer instead of a new Metal buffer per write.
  patches = [
    ./metal-outlined-debug-view.patch
    ./control.patch
    ./journal-texture-staging.patch
  ];
  prePatch = ''
    patch -d "$cargoDepsCopy/source-git-0/wgpu-hal-30.0.1" -p1 < ${./wgpu-hal-outlined-functions.patch}
  '';

  nativeBuildInputs = [cmake pkg-config (python3.withPackages (ps: [ps.pillow]))];
  buildInputs = [apple-sdk_15 aws-lc];
  cargoBuildFlags = ["-p" "aurora-viewer"];
  cargoTestFlags = ["--workspace"];
  # This existing HTTP fixture intermittently times out, including in isolation.
  # Exercise it separately from the rest of the complete suite.
  checkFlags = ["--skip" "viewer_statistics_leave_on_arrival_every_five_minutes_and_at_logout"];
  dontUseCargoParallelTests = true;
  # Upstream's release profile, tightened from thin LTO and 16 codegen units:
  # Vega compiles it once per source change. The tests keep the dev profile,
  # as upstream's CI does, rather than going through whole-program LTO.
  CARGO_PROFILE_RELEASE_LTO = "fat";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = 16;
  checkType = "debug";
  AURORA_VERSION_TAG = "v0.9.13+macos.e961b7df";

  postCheck = ''
    cargo test --workspace --locked --offline -j "$NIX_BUILD_CORES" \
      --target ${stdenv.hostPlatform.rust.rustcTarget} \
      viewer_statistics_leave_on_arrival_every_five_minutes_and_at_logout -- --test-threads=1
  '';

  postInstall = ''
    app="$out/Applications/Aurora Viewer.app/Contents"
    mkdir -p "$app/MacOS" "$app/Resources"
    mv "$out/bin/aurora-viewer" "$app/MacOS/aurora-viewer"
    ln -s "$app/MacOS/aurora-viewer" "$out/bin/aurora-viewer"
    cp ${./Info.plist} "$app/Info.plist"
    python -c 'from PIL import Image; import sys; Image.open("assets/branding/aurora-logo.png").save(sys.argv[1], format="ICNS")' \
      "$app/Resources/Aurora.icns"
    mkdir -p "$out/share/doc/aurora-viewer"
    cp LICENSE NOTICE.md "$out/share/doc/aurora-viewer/"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/aurora-viewer" --version)" = 'Aurora Viewer 0.9.13+macos.e961b7df'
    runHook postInstallCheck
  '';

  meta = {
    description = "Second Life viewer with a native Metal renderer on macOS";
    homepage = "https://github.com/Aurora-Viewer/Aurora-Viewer";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.darwin;
    mainProgram = "aurora-viewer";
  };
}
