{inputs, ...}: {
  flake.modules.homeManager = {
    catppuccin = inputs.catppuccin.homeModules.catppuccin;
    t3-code = inputs.t3-code-nix.homeModules.default;
  };

  flake-file.inputs = {
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    t3-code-nix = {
      url = "github:LisaScheers/t3-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
