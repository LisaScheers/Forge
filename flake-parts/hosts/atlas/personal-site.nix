{inputs, ...}: {
  flake-file.inputs.personal-website = {
    url = "github:LisaScheers/me";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  forge.modules.nixos.atlas = {
    imports = [inputs.personal-website.nixosModules.default];
    services.lisaWebsite.enable = true;
  };
}
