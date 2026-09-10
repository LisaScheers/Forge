inputs:
inputs.flake-parts.lib.mkFlake {inherit inputs;} {
  imports = [
    inputs.flake-parts.flakeModules.modules
    (inputs.import-tree.filter (path: !inputs.nixpkgs.lib.hasSuffix ".pkg.nix" path) ./flake-parts)
  ];
}
