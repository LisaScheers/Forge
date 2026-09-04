inputs:
inputs.flake-parts.lib.mkFlake {inherit inputs;} {
  imports = [
    inputs.flake-parts.flakeModules.modules
    (inputs.import-tree ./flake-parts)
  ];
}
