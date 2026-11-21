{lib, ...}: {
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
  # whole directory instead.
  config.flake.lib.runtimeSource = path:
    builtins.path {
      inherit path;
      name = baseNameOf path;
      filter = file: _: let
        name = baseNameOf file;
      in
        !(lib.hasPrefix "test_" name || name == "README.md" || name == ".gitignore");
    };
}
