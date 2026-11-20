{inputs, ...}: {
  # Per-system outputs cover the four nix-systems defaults; CI runs the three
  # that have native runners (see ci.nix).
  systems = import inputs.systems;

  flake-file.inputs.systems.url = "github:nix-systems/default";
}
