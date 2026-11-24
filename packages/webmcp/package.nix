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

  # The daemon omits a host, so Node would listen on every interface; the
  # bridge is meant for this machine's browser and agents only.
  postPatch = ''
    substituteInPlace build/index.js --replace-fail 'Ps.listen(e,()=>' 'Ps.listen(e,"127.0.0.1",()=>'
  '';

  # The published build is one esbuild bundle that imports only Node built-ins,
  # so none of package.json's npm dependencies are fetched or run. Its
  # package.json marks the bundle as an ES module.
  installPhase = ''
    runHook preInstall
    install -Dm644 build/index.js "$out/lib/webmcp/index.js"
    install -Dm644 package.json "$out/lib/webmcp/package.json"
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
