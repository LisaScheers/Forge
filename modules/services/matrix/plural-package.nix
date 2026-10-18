{
  overlays.pluralmatrix = final: _prev: {
    pluralmatrix = final.callPackage ../../../packages/pluralmatrix/pluralmatrix.pkg.nix {};
  };
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    packages = lib.optionalAttrs (system == "x86_64-linux") {pluralmatrix = pkgs.pluralmatrix;};
  };
}
