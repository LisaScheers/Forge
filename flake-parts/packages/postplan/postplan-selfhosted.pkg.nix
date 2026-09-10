{
  buildNpmPackage,
  fetchurl,
  lib,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}: let
  version = "0.0.4";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/postplan/-/postplan-${version}.tgz";
    hash = "sha512-ctOrqRP+MhkhbUi9xCPO8k9lYLbwzWs7IfKnBy1nTiFeLtWVLntWdvII4kIhtNJSioa+b4nOx/8+qAYN2aBUvg==";
  };
  source = stdenvNoCC.mkDerivation {
    pname = "postplan-source";
    inherit version;
    src = upstream;
    sourceRoot = "package";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R . "$out/"
      cp ${./postplan-package-lock.json} "$out/package-lock.json"
      runHook postInstall
    '';
  };
in
  buildNpmPackage {
    pname = "postplan-selfhosted";
    inherit version;
    src = source;

    npmDepsHash = "sha256-OuvS2ojMw2Sn6GC0FzGm2MqXrW1ZIeg0z7Ci9pgtNqE=";
    dontNpmBuild = true;
    nativeBuildInputs = [makeWrapper];

    postPatch = ''
      cp ${./postplan-config.js} src/config.js
      cp ${./postplan-authentik.js} src/authentik.js
      cp ${./postplan-storage.js} src/storage.js

      substituteInPlace src/web.js \
        --replace-fail 'from "./shoo.js"' 'from "./authentik.js"' \
        --replace-fail 'provider: "shoo"' 'provider: "authentik"'

      substituteInPlace src/web.js src/db.js src/render-web.js src/web-auth.js \
        --replace-warn 'shoo' 'Authentik'

      rm src/shoo.js
    '';

    postInstall = ''
      makeWrapper ${nodejs}/bin/node "$out/bin/postplan-server" \
        --add-flags "$out/lib/node_modules/postplan/src/server.js"
    '';

    meta = {
      description = "PostPlan HTML draft publishing with Authentik and local storage";
      homepage = "https://www.npmjs.com/package/postplan";
      license = lib.licenses.mit;
      mainProgram = "postplan";
      platforms = lib.platforms.unix;
    };
  }
