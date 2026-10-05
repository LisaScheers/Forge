{
  lib,
  stdenvNoCC,
  python3,
  git,
  git-credential-oauth,
  makeWrapper,
}: let
  oauthScopes = "write:repository write:user";
  # Use Forgejo's API client: the existing Git-only grant cannot change scope.
  oauthClientId = "d57cb8c4-630c-4168-8324-ec79935e18d4";
in
  stdenvNoCC.mkDerivation {
    pname = "forgejo-api";
    version = "0.1.0";
    src = ../../../tools/forgejo-api;
    nativeBuildInputs = [makeWrapper];
    nativeCheckInputs = [python3];
    dontBuild = true;
    doCheck = true;
    passthru = {inherit oauthScopes oauthClientId;};
    postPatch = ''
      substituteInPlace forgejo_api.py \
        --replace-fail '@oauthHelper@' '${lib.getExe git-credential-oauth}' \
        --replace-fail '@oauthClientId@' '${oauthClientId}' \
        --replace-fail '@oauthScopes@' '${oauthScopes}'
    '';
    checkPhase = ''
      runHook preCheck
      python3 -B -m unittest discover -s tests
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      install -Dm644 forgejo_api.py "$out/lib/forgejo-api/forgejo_api.py"
      makeWrapper ${python3}/bin/python3 "$out/bin/forgejo-api" \
        --add-flags "$out/lib/forgejo-api/forgejo_api.py" \
        --prefix PATH : ${lib.makeBinPath [git]}
      runHook postInstall
    '';
    meta = {
      description = "Call Lisa's Forgejo API using Git's stored OAuth credentials";
      mainProgram = "forgejo-api";
      platforms = lib.platforms.unix;
    };
  }
