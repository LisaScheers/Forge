{
  lib,
  stdenvNoCC,
  python3,
  nodejs,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "chrome-tab";
  version = "0.1.0";
  src = ../../../tools/chrome-tab;
  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [python3 nodejs];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -B -m unittest discover -s tests -p 'test_*.py'
    node --test tests/extension.test.cjs
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/chrome-tab" "$out/share/chrome-tab" "$out/bin"
    cp chrome_tab.py "$out/lib/chrome-tab/"
    cp -R extension "$out/share/chrome-tab/"
    cp README.md "$out/share/chrome-tab/"
    makeWrapper ${python3}/bin/python3 "$out/bin/chrome-tab" \
      --add-flags "$out/lib/chrome-tab/chrome_tab.py"
    makeWrapper "$out/bin/chrome-tab" "$out/bin/chrome-tab-native-host" \
      --add-flags native-host
    runHook postInstall
  '';
  meta = {
    description = "Evaluate JavaScript in explicitly connected Chrome tabs";
    mainProgram = "chrome-tab";
    platforms = lib.platforms.unix;
  };
}
