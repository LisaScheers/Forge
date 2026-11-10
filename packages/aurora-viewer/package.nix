{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  python3,
  apple-sdk_15,
}:
rustPlatform.buildRustPackage {
  pname = "aurora-viewer";
  version = "0.9.5-unstable-2026-11-10";

  src = fetchFromGitHub {
    owner = "Aurora-Viewer";
    repo = "Aurora-Viewer";
    rev = "a211db389e335f815ca6f1b9b4a4e2271cea000e";
    hash = "sha256-hIfMrSjuzB9IYsHAyCclo8RjvUu6BR4EM+h7WlRjbr4=";
  };

  cargoHash = "sha256-SQHMcrjGR1PkBhFQ8ysQPB+UQeErp72Y/CC4hye9Y7k=";
  # Reject transparent blended texels before fetching the remaining material maps.
  patches = [./macos.patch];

  nativeBuildInputs = [cmake pkg-config (python3.withPackages (ps: [ps.pillow]))];
  buildInputs = [apple-sdk_15];
  cargoBuildFlags = ["-p" "aurora-viewer"];
  cargoTestFlags = ["--workspace"];
  # This existing HTTP fixture intermittently times out, including in isolation.
  # Exercise it separately from the rest of the complete suite.
  checkFlags = ["--skip" "viewer_statistics_leave_on_arrival_every_five_minutes_and_at_logout"];
  dontUseCargoParallelTests = true;
  buildType = "debug";
  AURORA_VERSION_TAG = "v0.9.5+macos.a211db38";

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
    test "$("$out/bin/aurora-viewer" --version)" = 'Aurora Viewer 0.9.5+macos.a211db38'
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
