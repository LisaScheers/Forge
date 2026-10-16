{
  config,
  inputs,
  ...
}: {
  home.lisa-cli.imports = [config.home.catppuccin];
  home."lisa" = {
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
