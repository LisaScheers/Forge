{
  lib,
  stdenvNoCC,
  python3,
  nodejs,
  makeWrapper,
}: let
  extensionId = "fjgenihlcmobdjmfnmnhmglpemfkklle";
in
  stdenvNoCC.mkDerivation {
    pname = "chrome-tab";
    version = "0.1.0";
    src = ../../../tools/chrome-tab;
    nativeBuildInputs = [makeWrapper];
    nativeCheckInputs = [python3 nodejs];
    dontBuild = true;
    doCheck = true;
    passthru = {inherit extensionId;};
    checkPhase = ''
      runHook preCheck
      python3 - <<'PY'
      import base64, hashlib, json
      with open("extension/manifest.json") as manifest_file:
          public_key = base64.b64decode(json.load(manifest_file)["key"], validate=True)
      extension_id = hashlib.sha256(public_key).hexdigest()[:32].translate(
          str.maketrans("0123456789abcdef", "abcdefghijklmnop")
      )
      assert extension_id == "${extensionId}", extension_id
      PY
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
