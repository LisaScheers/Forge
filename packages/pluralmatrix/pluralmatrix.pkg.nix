{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  buildNpmPackage,
  rustPlatform,
  nodejs_22,
  openssl,
  autoPatchelfHook,
  makeWrapper,
  pkg-config,
  sqlite,
}: let
  version = "unstable-2026-10-18";
  src = fetchFromGitHub {
    owner = "pluralmatrix";
    repo = "pluralmatrix";
    rev = "d10e51a4c9fe12cdab226b8241f85716fe37f50f";
    hash = "sha256-Pq8aOQhg4qGkHYNX64Uj7m4OIZSvpzoS/vGwvqSeHJY=";
  };
  engines = stdenv.mkDerivation {
    pname = "pluralmatrix-prisma-engines";
    version = "5.22.0";
    dontUnpack = true;
    queryEngine = fetchurl {
      url = "https://binaries.prisma.sh/all_commits/605197351a3c8bdd595af2d2a9bc3025bca48ea2/debian-openssl-3.0.x/libquery_engine.so.node.gz";
      hash = "sha256-ETwMIJMjMgZmjH6QGD7GVwYYlyx9mo2ydEeunFViCjQ=";
    };
    schemaEngine = fetchurl {
      url = "https://binaries.prisma.sh/all_commits/605197351a3c8bdd595af2d2a9bc3025bca48ea2/debian-openssl-3.0.x/schema-engine.gz";
      hash = "sha256-rzzzPHOpUM3GJvkhU08lQ7rNspdq3RKxMRRW9YZtvhU=";
    };
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [openssl stdenv.cc.cc.lib];
    installPhase = ''
      mkdir -p $out/lib $out/bin
      gzip -dc "$queryEngine" > $out/lib/libquery_engine.so.node
      gzip -dc "$schemaEngine" > $out/bin/schema-engine
      chmod +x $out/bin/schema-engine
    '';
  };
  frontend = buildNpmPackage {
    pname = "pluralmatrix-client";
    inherit version;
    src = "${src}/app-service/client";
    patches = [./client-auth.patch];
    nodejs = nodejs_22;
    npmDepsHash = "sha256-jjM2VEdKAGCHlQ3xlIdbOqo9f4TRiD52D7qlIm2rZzQ=";
    installPhase = ''
      mkdir -p $out
      cp -r dist $out/
    '';
  };
  cryptoHelper = rustPlatform.buildRustPackage {
    pname = "pluralmatrix-crypto-helper";
    inherit version;
    src = "${src}/rust-crypto-helper";
    cargoHash = "sha256-UAMPap2B26raZmU6ewFOLmhjbX2kq+88vSpfxssO1xc=";
    nativeBuildInputs = [pkg-config];
    buildInputs = [openssl sqlite];
  };
  cryptoNode = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };
in
  buildNpmPackage {
    pname = "pluralmatrix";
    inherit version;
    src = "${src}/app-service";
    patches = [./integration.patch];
    nodejs = nodejs_22;
    npmDepsHash = "sha256-DfhNtoYYw4uvhlLNgKE2nl0CKTLBxLkRxkuDSmMAvao=";
    nativeBuildInputs = [autoPatchelfHook makeWrapper];
    buildInputs = [openssl stdenv.cc.cc.lib];
    env = {
      PRISMA_SKIP_POSTINSTALL_GENERATE = "1";
      PRISMA_QUERY_ENGINE_LIBRARY = "${engines}/lib/libquery_engine.so.node";
      PRISMA_SCHEMA_ENGINE_BINARY = "${engines}/bin/schema-engine";
    };
    dontNpmBuild = true;
    doCheck = true;
    checkPhase = ''
      node node_modules/jest/bin/jest.js --runInBand --forceExit \
        --testPathPatterns='utils/(avatarDownload|proxyParser|commandParser|privacy|timeParser).test|schemas/(member|import).test'
    '';
    buildPhase = ''
      runHook preBuild
      cp ${cryptoNode} node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node
      node node_modules/prisma/build/index.js generate
      node node_modules/typescript/bin/tsc
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/pluralmatrix/client $out/bin
      cp -r dist node_modules prisma $out/lib/pluralmatrix/
      cp -r ${frontend}/dist $out/lib/pluralmatrix/client/
      cp -r ${src}/assets $out/lib/pluralmatrix/
      makeWrapper ${nodejs_22}/bin/node $out/bin/pluralmatrix \
        --add-flags "$out/lib/pluralmatrix/dist/index.js" \
        --set NODE_ENV production \
        --set PRISMA_QUERY_ENGINE_LIBRARY ${engines}/lib/libquery_engine.so.node \
        --set PRISMA_SCHEMA_ENGINE_BINARY ${engines}/bin/schema-engine \
        --set RUST_HELPER_PATH ${cryptoHelper}/bin/rust-crypto-helper
      makeWrapper ${nodejs_22}/bin/node $out/bin/pluralmatrix-migrate \
        --add-flags "$out/lib/pluralmatrix/node_modules/prisma/build/index.js migrate deploy --schema $out/lib/pluralmatrix/prisma/schema.prisma" \
        --set PRISMA_QUERY_ENGINE_LIBRARY ${engines}/lib/libquery_engine.so.node \
        --set PRISMA_SCHEMA_ENGINE_BINARY ${engines}/bin/schema-engine \
        --prefix PATH : ${lib.makeBinPath [openssl]}
      runHook postInstall
    '';
    passthru = {inherit frontend cryptoHelper engines;};
    meta = {
      description = "PluralKit-style member proxying for Matrix";
      homepage = "https://pluralmatrix.org/";
      platforms = ["x86_64-linux"];
      mainProgram = "pluralmatrix";
    };
  }
