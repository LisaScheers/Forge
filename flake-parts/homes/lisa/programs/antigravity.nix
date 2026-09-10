{inputs, ...}: {
  forge.overlays.antigravity-cli = final: _prev: {
    antigravity-cli = inputs.antigravity-cli.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.antigravity-cli = {
    url = "github:selfhost-it/antigravity-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
