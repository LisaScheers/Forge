{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_22,
}: let
  version = "0.0.14";
in
  (buildNpmPackage.override {nodejs = nodejs_22;}) {
    pname = "obsidian-headless";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
      hash = "sha512-S1d/hxLKvCUG2g5tRyXFkzPqMs3Ntw1tDyzoF2yfHGRuB4B+Mi3X2vgT8LbfQKrkEEi3LfJRdXtYzAVHcbpccw==";
    };
    sourceRoot = "package";

    postPatch = ''
      cp ${./obsidian-headless-package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-Pcy6hxgc9MyTe/a7bE4pMtXjG9hx4HNwZgbfIzTtVRQ=";
    dontNpmBuild = true;
    env.npm_config_build_from_source = "true";

    meta = {
      description = "Headless client for Obsidian Sync";
      homepage = "https://github.com/obsidianmd/obsidian-headless";
      license = lib.licenses.unfree;
      mainProgram = "ob";
      platforms = lib.platforms.unix;
    };
  }
