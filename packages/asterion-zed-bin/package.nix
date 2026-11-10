{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  gcc,
  glib,
  alsa-lib,
  libxkbcommon,
  libxcb,
  libx11,
  libGL,
  vulkan-loader,
  wayland,
  fontconfig,
  nodejs,
  bubblewrap,
  ncurses,
  ghostty,
}: let
  sourceCommit = "b5cd310b3b54dfc659fcc06453e6358843dfe216";
  sourceVersion = "1.29.0+nightly.3504.${sourceCommit}";
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "asterion-zed-bin";
    version = "1.29.0-nightly.3504";
    src = fetchurl {
      name = "${finalAttrs.pname}-${finalAttrs.version}.tar.gz";
      url = "https://zed-nightly-host.nyc3.digitaloceanspaces.com/${sourceVersion}/zed-linux-aarch64.tar.gz";
      hash = "sha256-ufNeblU1+cp4/O9FAL4M+50j4KpIkXHrUwMBpt2ngM0=";
    };
    nativeBuildInputs = [autoPatchelfHook makeWrapper];
    buildInputs = [gcc.cc.lib glib alsa-lib libxkbcommon libxcb libx11];
    runtimeDependencies = map lib.getLib [libGL vulkan-loader wayland fontconfig];
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r . "$out/"
      # Use one Nix library set, including the C++ runtime needed by Mesa.
      rm -rf "$out/lib"
      substituteInPlace "$out/share/applications/dev.zed.Zed-Nightly.desktop" \
        --replace-fail 'Exec=zed' "Exec=$out/bin/zed"
      ln -s zed "$out/bin/zeditor"
      # Nightly hosting expires old artifacts; retain the pinned input for rebuilds.
      mkdir -p "$out/nix-support"
      echo '${finalAttrs.src}' > "$out/nix-support/source"
      runHook postInstall
    '';

    postFixup = ''
      wrapProgram "$out/libexec/zed-editor" \
        --set ZED_UPDATE_EXPLANATION "Updates are managed by Nix." \
        --suffix PATH : ${lib.makeBinPath [nodejs bubblewrap]} \
        --prefix TERMINFO_DIRS : ${lib.escapeShellArg "${ghostty.terminfo}/share/terminfo:${ncurses}/share/terminfo"}
    '';

    doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
    installCheckPhase = ''
      runHook preInstallCheck
      version_output=$("$out/bin/zed" --version)
      echo "$version_output"
      echo "$version_output" | grep -F '1.29.0'
      echo "$version_output" | grep -F 'b5cd310'
      ldd "$out/libexec/.zed-editor-wrapped" > dependencies.txt
      cat dependencies.txt
      if grep -F 'not found' dependencies.txt; then
        exit 1
      fi
      runHook postInstallCheck
    '';

    passthru = {inherit sourceCommit sourceVersion;};
    meta = {
      description = "Pinned official ARM Linux Zed Nightly binary for Asterion";
      homepage = "https://zed.dev/";
      license = lib.licenses.gpl3Plus;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-linux"];
      mainProgram = "zed";
    };
  })
