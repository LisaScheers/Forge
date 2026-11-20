{inputs, ...}: {
  # Nook's applications (Home Assistant and its components, Sonarr) come from
  # their own pin, held apart from the system Nixpkgs; modules use pkgs.nookApps.
  flake-file.inputs.nixpkgs-nook-apps.url = "github:NixOS/nixpkgs/master";
  overlays.nook-apps = final: _prev: {
    nookApps = inputs.nixpkgs-nook-apps.legacyPackages.${final.stdenv.hostPlatform.system};
  };
}
