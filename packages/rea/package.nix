{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_26,
  procps,
  stdenv,
  autoPatchelfHook,
}: let
  fridaPlatform =
    {
      aarch64-darwin = {
        name = "darwin-arm64";
        hash = "sha256:850fba220a2d9b6aae282ac6dde37f48847e73597b7a06d648737ff9addc3340";
      };
      x86_64-darwin = {
        name = "darwin-x64";
        hash = "sha256:f8953b09720cbdccd271c1d6caa4fff085474a9f24def3fe46160526aacdb40b";
      };
      aarch64-linux = {
        name = "linux-arm64";
        hash = "sha256:11083f016a429e87506cd68166bd1445da8febd506a24edf3f6c4a9a7a3ea9fe";
      };
      x86_64-linux = {
        name = "linux-x64";
        hash = "sha256:9fa8f668ce91eb03713e8564de4f8fbde232233ee91d729c16773fde11dbae95";
      };
    }.${
      stdenv.hostPlatform.system
    };
  fridaBinding = fetchurl {
    url = "https://github.com/frida/frida/releases/download/17.23.2/frida-v17.23.2-napi-v8-${fridaPlatform.name}.tar.gz";
    hash = fridaPlatform.hash;
  };
in
  buildNpmPackage {
    pname = "rea";
    version = "6.8.0";

    src = fetchurl {
      url = "https://registry.npmjs.org/rea-agents/-/rea-agents-6.8.0.tgz";
      hash = "sha256-jVQux2qcs1BYS2CmycCIcG/4EtW7WwlMIMlbbcJWmLs=";
    };
    postPatch = ''
      cp ${fetchurl {
        url = "https://raw.githubusercontent.com/morluto/rea/160d821ac9a0310afcb8d1fc427862dd6508add5/package-lock.json";
        hash = "sha256-HY+g8zsxJdPmAeyDKxjZ01s3RT82NA3AUH8GWo3hWK0=";
      }} package-lock.json
    '';

    nodejs = nodejs_26;
    npmDepsHash = "sha256-3WPXD+qm5WVfrTEvepKwX5RZBfbLBcPB0uDmKIx4MR8=";
    npmFlags = ["--ignore-scripts"];
    npmInstallFlags = ["--omit=dev"];
    dontNpmBuild = true;

    nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

    postInstall = ''
      # Supply the exact upstream native binding without npm's networked install hook.
      tar -xzf ${fridaBinding} -C "$out/lib/node_modules/rea-agents/node_modules/frida"
      for command_name in rea rea-agents; do
        wrapProgram "$out/bin/$command_name" \
          --prefix PATH : ${lib.makeBinPath ([nodejs_26] ++ lib.optionals stdenv.hostPlatform.isLinux [procps])}
      done
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      test -f "$out/lib/node_modules/rea-agents/skills/reverse-engineer-anything/SKILL.md"
      "$out/bin/rea" --version
      ${nodejs_26}/bin/node --input-type=module -e \
        'const frida = await import(process.argv[1]); if (typeof frida.getDeviceManager !== "function") throw new Error("Frida binding unavailable");' \
        "$out/lib/node_modules/rea-agents/node_modules/frida/build/src/frida.js"
      ${nodejs_26}/bin/node ${./test-mcp.mjs} "$out/bin/rea"
      runHook postInstallCheck
    '';

    meta = {
      description = "Reverse engineering CLI and MCP server";
      homepage = "https://github.com/morluto/rea";
      license = lib.licenses.mit;
      mainProgram = "rea";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
