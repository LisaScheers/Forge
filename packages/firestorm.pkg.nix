{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
}: let
  version = "7.2.5.81788";
  releaseName = "Phoenix-Firestorm-Releasex64_AVX2-7-2-5-81788";

  firestorm-unwrapped = stdenvNoCC.mkDerivation {
    pname = "firestorm-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://downloads.firestormviewer.org/release/linux/${releaseName}.tar.xz";
      hash = "sha256-yaDbscQHbxd6wv9eG2LY/cWCVPBN64VLrrNSDFO1s9o=";
    };

    sourceRoot = releaseName;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/opt/firestorm"
      cp -a . "$out/opt/firestorm/"

      runHook postInstall
    '';
  };
in
  buildFHSEnv {
    pname = "firestorm";
    inherit version;

    targetPkgs = pkgs: [
      pkgs.alsa-lib
      pkgs.at-spi2-atk
      pkgs.at-spi2-core
      pkgs.cairo
      pkgs.cups.lib
      pkgs.dbus
      pkgs.dbus-glib
      pkgs.expat
      pkgs.fontconfig
      pkgs.freetype
      pkgs.glib
      pkgs.gtk3
      pkgs.libGL
      pkgs.libGLU
      pkgs.libX11
      pkgs.libXcomposite
      pkgs.libXcursor
      pkgs.libXdamage
      pkgs.libXext
      pkgs.libXfixes
      pkgs.libXi
      pkgs.libXinerama
      pkgs.libXrandr
      pkgs.libXrender
      pkgs.libXxf86vm
      pkgs.libdrm
      pkgs.libgbm
      pkgs.libnotify
      pkgs.libpulseaudio
      pkgs.libuuid
      pkgs.libxcb
      pkgs.libxkbcommon
      pkgs.mesa
      pkgs.nspr
      pkgs.nss
      pkgs.pango.out
      pkgs.stdenv.cc.cc.lib
      pkgs.udev
      pkgs.zlib
    ];

    runScript = "${firestorm-unwrapped}/opt/firestorm/firestorm";

    meta = {
      description = "Third-party viewer for Second Life and OpenSim";
      homepage = "https://www.firestormviewer.org/";
      license = lib.licenses.lgpl21Plus;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "firestorm";
    };
  }
