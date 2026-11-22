{
  config,
  inputs,
  ...
}: {
  home.lisa = {
    imports = [config.home.catppuccin];
    catppuccin = {
      enable = true;
      flavor = "mocha";
      accent = "pink";
      autoEnable = true;
    };
  };
  home.catppuccin = inputs.catppuccin.homeModules.catppuccin;
  flake-file.inputs.catppuccin = {
    url = "github:catppuccin/nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
