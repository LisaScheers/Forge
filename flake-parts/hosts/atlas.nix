{inputs, ...}: {
  flake.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ./_atlas
      (import ./_atlas/pony-tack.nix {inherit config inputs pkgs;})
    ];
  };

  flake-file.inputs = {
    pony-tack = {
      flake = false;
      url = "git+ssh://git@ssh.github.com:443/LisaScheers/sl-pony-tack.git?ref=main";
    };
    shop-empty-track = {
      url = "github:LisaScheers/shop-empty-track/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sl-remote = {
      url = "github:LisaScheers/sl-remote/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
