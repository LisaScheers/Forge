{inputs, ...}: {
  forge.modules.homeManager.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  forge.modules.homeManager."lisa@nook" = {pkgs, ...}: {
    services.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
      host = "0.0.0.0";
      port = 3773;
      dataDirectory = "/srv/disks/projects/projects/.t3code";
      providerPackages = [
        pkgs.codex
      ];
    };
  };
  forge.modules.homeManager."lisa@vega" = {
    programs.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
    };
  };
}
