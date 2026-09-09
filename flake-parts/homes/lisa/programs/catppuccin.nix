{inputs, ...}: {
  forge.modules.homeManager."lisa" = {
    catppuccin = {
      enable = true;
      flavor = "mocha";
      accent = "pink";
      autoEnable = true;
    };
  };
  forge.modules.homeManager.catppuccin = inputs.catppuccin.homeModules.catppuccin;
  flake-file.inputs.catppuccin = {
    url = "github:catppuccin/nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
