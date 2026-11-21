{inputs, ...}: {
  # Per-system outputs cover the nix-systems defaults; ci.nix maps each to a
  # native runner and fails evaluation for one without.
  systems = import inputs.systems;

  flake-file.inputs.systems.url = "github:nix-systems/default";
}
