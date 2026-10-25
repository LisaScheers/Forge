{inputs, ...}: {
  flake-file.inputs.helium = {
    url = "github:schembriaiden/helium-browser-nix-flake/ebac6e7f4af50aa48200ae77ea6606061e2d3e84";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nixpkgs-darwin.follows = "nixpkgs";
  };

  home.lisa-asterion = {
    lib,
    pkgs,
    ...
  }: let
    helium = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    home.packages = [helium];
    home.sessionVariables.BROWSER = lib.getExe helium;
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = ["helium.desktop"];
        "application/xhtml+xml" = ["helium.desktop"];
        "x-scheme-handler/http" = ["helium.desktop"];
        "x-scheme-handler/https" = ["helium.desktop"];
      };
    };
  };
}
