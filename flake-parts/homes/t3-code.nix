{inputs, ...}: {
  forge.modules.homeManager.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  forge.modules.homeManager."lisa@vega" = {
    programs.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
    };
  };
}
