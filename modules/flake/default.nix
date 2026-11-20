{lib, ...}: {
  flake-file = {
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
  debug = true;
}
