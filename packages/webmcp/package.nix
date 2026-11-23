{
  fetchurl,
  lib,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "webmcp";
  version = "0.1.13";

  src = fetchurl {
    url = "https://registry.npmjs.org/@jason.today/webmcp/-/webmcp-${finalAttrs.version}.tgz";
    hash = "sha512-FpFfgZFhLukAphGLK6SkM8NHvqdsVIRfqy2cOlyrU+TNGp7FugL8y2sXx87lrgEhlfdDdxdF7Ywaf4XN/IlXDA==";
  };

  nativeBuildInputs = [makeWrapper];

  # The published build is one esbuild bundle that imports only Node built-ins,
  # so none of package.json's npm dependencies are fetched or run.
  installPhase = ''
    runHook preInstall
    install -Dm644 build/index.js "$out/lib/webmcp/index.js"
    makeWrapper ${lib.getExe nodejs} "$out/bin/webmcp" --add-flags "$out/lib/webmcp/index.js"
    runHook postInstall
  '';

  meta = {
    description = "WebSocket bridge that exposes web page tools to MCP clients";
    homepage = "https://github.com/jasonjmcghee/webmcp";
    license = lib.licenses.mit;
    mainProgram = "webmcp";
  };
})
