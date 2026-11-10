{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
}: let
  platform =
    {
      aarch64-darwin = {
        name = "macos-arm64";
        hash = "sha256:9dff8e2de5cc2afd359c57fddf4a868a57c66cfd9e22732d37bb4ed4e794a17a";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256:c027d616b005fa09c77783c332db2e3414de7a67dde2d93e73bb7adae0f8fab3";
      };
      aarch64-linux = {
        name = "linux-arm64";
        hash = "sha256:473c9885574540f340f0ab1a50ac8e7f18b244b4d2ee98156ebfc81a595077d8";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256:cc8b329131376a510e1f7457eb3c38ff05372b4c455f5d4fa09f0bc4fed6c118";
      };
    }.${
      stdenv.hostPlatform.system
    };
  specs = fetchurl {
    url = "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-specs.tar.gz";
    hash = "sha256:f29c028405b3042a5f863db9d9f65564359e1e5786928f1b367d6bf652c50936";
  };
in
  stdenv.mkDerivation {
    pname = "rea-kuna";
    version = "1.994";
    src = fetchurl {
      url = "https://github.com/Noelo-Lab/kuna/releases/download/v1.994/kuna-v1.994-${platform.name}.tar.gz";
      hash = platform.hash;
    };
    nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 kuna "$out/bin/kuna"
      install -Dm644 -t "$out/share/licenses/kuna" LICENSE NOTICE
      mkdir -p "$out/share/kuna/specs"
      tar -xzf ${specs} -C "$out/share/kuna/specs" --strip-components=1
      wrapProgram "$out/bin/kuna" --set-default KUNA_SPECS "$out/share/kuna/specs"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/kuna" --version | grep '1.994'
      test -d "$out/share/kuna/specs"
      runHook postInstallCheck
    '';
    meta = {
      description = "Kuna decompiler for REA";
      homepage = "https://github.com/Noelo-Lab/kuna";
      license = lib.licenses.asl20;
      mainProgram = "kuna";
      platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
