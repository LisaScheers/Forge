{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation {
  pname = "rea-wakaru";
  version = "1.14.0";
  src = fetchurl {
    url = "https://github.com/pionxzh/wakaru/releases/download/v1.14.0/wakaru-linux-x64.tar.gz";
    hash = "sha256:db0e620034723195ab426e94d00d55dbd8fd0106a928ada2563f1103196d09fa";
  };
  dontUnpack = true;
  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    tar -xzf "$src" wakaru
    install -Dm755 wakaru "$out/bin/wakaru"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/wakaru" --version | grep '1.14.0'
    runHook postInstallCheck
  '';
  meta = {
    description = "JavaScript source recovery at REA's verified Wakaru release";
    homepage = "https://github.com/pionxzh/wakaru";
    license = lib.licenses.mit;
    mainProgram = "wakaru";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
