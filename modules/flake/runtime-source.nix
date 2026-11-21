{
  config,
  lib,
  ...
}: {
  # A service's files under services/<name>/ without its tests, notes and
  # Authentik blueprint (applied from its own copy), so editing those never
  # changes or restarts what runs. Its check reads the whole directory instead.
  # Any file named test_* at any depth counts as a test, including test-only
  # helpers and fixtures.
  flake.lib.runtimeSource = path:
    builtins.path {
      inherit path;
      name = baseNameOf path;
      filter = file: _: let
        name = baseNameOf file;
      in
        !(lib.hasPrefix "test_" name || builtins.elem name ["README.md" ".gitignore" "authentik.yaml"]);
    };

  # full/app is clean/app plus a test, a nested test helper, notes and a
  # blueprint, so both must give the same store path.
  perSystem = {pkgs, ...}: {
    checks.runtime-source = let
      inherit (config.flake.lib) runtimeSource;
    in
      assert lib.assertMsg (runtimeSource ./runtime-source/full/app == runtimeSource ./runtime-source/clean/app) "runtimeSource must drop tests, notes and blueprints at any depth, and nothing else";
        pkgs.runCommand "runtime-source" {} ''
          test -f ${runtimeSource ./runtime-source/full/app}/public/app.js
          touch "$out"
        '';
  };
}
