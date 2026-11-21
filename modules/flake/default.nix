{
  config,
  lib,
  ...
}: {
  config.flake-file = {
    outputs = "dendritic";
    description = "Multi-host Nix configuration for Darwin and NixOS";

    do-not-edit = lib.concatLines (
      map (line: "# ${line}") (
        lib.splitString "\n" ''
          This flake.nix file is auto-generated.
          The source of truth is merged from flake-parts modules under modules/.
          Regenerate with: nix run .#write-flake
          https://flake-file.denful.dev/''
      )
    );
  };
  # nixd reads flake-parts and flake-file option docs from the debug output.
  config.debug = true;
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Functions Forge exports to its tools and modules: nixd settings, profile lookup, runtime sources.";
  };
  # A service's files under services/<name>/ without its tests and notes, so
  # editing those never changes or restarts what runs. Its check reads the
  # whole directory instead. Any file named test_* at any depth counts as a
  # test, including test-only helpers and fixtures.
  config.flake.lib.runtimeSource = path:
    builtins.path {
      inherit path;
      name = baseNameOf path;
      filter = file: _: let
        name = baseNameOf file;
      in
        !(lib.hasPrefix "test_" name || name == "README.md" || name == ".gitignore");
    };
  config.perSystem = {pkgs, ...}: {
    checks.runtime-source = let
      runtimeFiles = name: builtins.attrNames (builtins.readDir (config.flake.lib.runtimeSource (../../services + "/${name}")));
      watchRoom = runtimeFiles "watch-room";
      aiUsage = runtimeFiles "ai-usage";
    in
      assert lib.assertMsg (builtins.elem "server.py" watchRoom && builtins.all (name: !(builtins.elem name watchRoom)) ["test_server.py" "README.md" ".gitignore"]) "runtimeSource must keep Watch Room's server and drop its tests and notes";
      assert lib.assertMsg (builtins.elem "ingest.py" aiUsage && builtins.all (name: !(lib.hasPrefix "test_" name)) aiUsage) "runtimeSource must drop AI usage's test helpers";
        pkgs.runCommand "runtime-source" {} ''
          touch "$out"
        '';
  };
}
