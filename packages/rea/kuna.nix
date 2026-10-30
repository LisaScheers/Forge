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
        hash = "sha256:6d5f2157bf7aef705c670b044a38f69574e184bf0ebd062f2a0d5e0545844c90";
      };
      x86_64-darwin = {
        name = "macos-x86_64";
        hash = "sha256:6b1c45bc28c0b4281599ce757762b8bd4f6c13df94352e564aaa7dc980af2df0";
      };
      aarch64-linux = {
        name = "linux-arm64";
        hash = "sha256:c1f7cd7cdb990cdf1149d2f595a56adf3a4afce052d014b2b6670adbfbcc71e5";
      };
      x86_64-linux = {
        name = "linux-x86_64";
        hash = "sha256:e9f047fb5a93925ede6d869df22c26c1c0ced90764ace7467ae90f880625d530";
      };
    }.${
      stdenv.hostPlatform.system
    };
  specs = fetchurl {
    url = "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-specs.tar.gz";
    hash = "sha256:57d7b6976dc8844d54ddff3c54c742c372a17b3a48a8898499d4e23cce232550";
  };
in
  stdenv.mkDerivation {
    pname = "rea-kuna";
    version = "1.833";
    src = fetchurl {
      url = "https://github.com/Noelo-Lab/kuna/releases/download/v1.833/kuna-v1.833-${platform.name}.tar.gz";
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
      wrapProgram "$out/bin/kuna" --set-default KUNA_ROOT "$out/share/kuna"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/kuna" --version | grep '1.833'
      test -d "$out/share/kuna/specs"
      runHook postInstallCheck
    '';
    meta = {
      description = "Kuna decompiler at REA's verified release";
      homepage = "https://github.com/Noelo-Lab/kuna";
      license = lib.licenses.asl20;
      mainProgram = "kuna";
      platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
