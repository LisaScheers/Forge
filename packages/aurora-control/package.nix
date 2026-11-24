{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "aurora-control";
  version = "1.0.0";
  src = ../../tools/aurora-control;
  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [python3];
  dontBuild = true;
  doCheck = true;
  # Client, CLI and MCP framing, against a stand-in viewer socket. The
  # end-to-end check (e2e_demo.py) needs a running offline demo.
  checkPhase = ''
    runHook preCheck
    python3 -B -m unittest discover -s tests -p 'test_*.py'
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    lib="$out/lib/aurora-control"
    mkdir -p "$lib" "$out/bin"
    cp viewer_api.py aurora_control.py mcp_server.py e2e_demo.py tools.json guide.md README.md "$lib/"
    makeWrapper ${python3}/bin/python3 "$out/bin/aurora-control" --add-flags "-s $lib/aurora_control.py"
    makeWrapper ${python3}/bin/python3 "$out/bin/aurora-control-mcp" --add-flags "-s $lib/mcp_server.py"
    runHook postInstall
  '';
  meta = {
    description = "Client, CLI and MCP server for Aurora Viewer's local control bridge";
    mainProgram = "aurora-control";
    platforms = lib.platforms.unix;
  };
}
