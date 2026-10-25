{
  lib,
  stdenv,
  fetchzip,
  meson,
  ninja,
  pkg-config,
  bison,
  flex,
  python3Packages,
  glslang,
  llvmPackages,
  spirv-llvm-translator,
  spirv-tools,
  elfutils,
  expat,
  libdrm,
  libdisplay-info,
  libgbm,
  libglvnd,
  libunwind,
  udev,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libx11,
  libxcb,
  libxext,
  libxfixes,
  libxrandr,
  libxshmfence,
  libxxf86vm,
  libxcb-keysyms,
  xorgproto,
  zstd,
}:
stdenv.mkDerivation {
  pname = "asterion-gpu-test-mesa";
  version = "26.3.0-devel-agx3b-d859e435";

  src = fetchzip {
    url = "https://github.com/aurora-silicon/mesa/archive/d859e435edc44bf6732b72686867bff8c7f4c002.tar.gz";
    hash = "sha256-oNcY6lu/vJm7cHV1e99nDPQesFkcS0k87Dc6oJXOfWs=";
  };

  strictDeps = true;
  enableParallelBuilding = true;
  # Share the builder with the test kernel without exhausting its memory.
  ninjaFlags = ["-j6"];

  # This fork looks for Clang in LLVM's directory; Nix splits their libraries.
  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail "llvm_libdir = dep_llvm.get_variable(cmake : 'LLVM_LIBRARY_DIR', configtool: 'libdir')" \
        "llvm_libdir = '${lib.getLib llvmPackages.clang-unwrapped}/lib'"
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    bison
    flex
    python3Packages.python
    python3Packages.packaging
    python3Packages.mako
    python3Packages.ply
    python3Packages.pyyaml
    (lib.getBin glslang)
    wayland-scanner
  ];

  buildInputs = [
    llvmPackages.clang-unwrapped
    (lib.getLib llvmPackages.clang-unwrapped)
    llvmPackages.libllvm
    spirv-llvm-translator
    spirv-tools
    elfutils
    expat
    libdrm
    libdisplay-info
    libgbm
    libglvnd
    libunwind
    udev
    wayland
    wayland-protocols
    libx11
    libxcb
    libxext
    libxfixes
    libxrandr
    libxshmfence
    libxxf86vm
    libxcb-keysyms
    xorgproto
    zstd
  ];

  preConfigure = ''
    export PATH=${lib.getDev llvmPackages.libllvm}/bin:$PATH
  '';

  mesonFlags = [
    "-Dgallium-drivers=asahi"
    "-Dvulkan-drivers=asahi"
    "-Dplatforms=x11,wayland"
    "-Dvulkan-layers="
    "-Dglvnd=enabled"
    "-Dgbm=enabled"
    "-Dlibgbm-external=true"
    "-Dgallium-rusticl=false"
    "-Dgallium-va=disabled"
    "-Dgallium-mediafoundation=disabled"
    "-Dmicrosoft-clc=disabled"
    "-Dandroid-libbacktrace=disabled"
    "-Dlmsensors=disabled"
    "-Dvideo-codecs="
    "-Dvalgrind=disabled"
    "-Dbuild-tests=false"
    "-Db_ndebug=true"
  ];

  postFixup = ''
    substituteInPlace "$out/share/glvnd/egl_vendor.d/50_mesa.json" \
      --replace-fail '"libEGL_mesa.so.0"' '"'"$out/lib/libEGL_mesa.so.0"'"'
  '';

  passthru = {
    sourceRevision = "d859e435edc44bf6732b72686867bff8c7f4c002";
    kernelRevision = "b6f070c911934c9c377c4be939b883bf32f37acf";
  };

  meta = {
    description = "Isolated experimental G15S Mesa for Asterion's tethered GPU test";
    homepage = "https://github.com/aurora-silicon/mesa";
    license = lib.licenses.mit;
    platforms = ["aarch64-linux"];
  };
}
