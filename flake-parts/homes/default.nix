{lib, ...}: {
  options.flake.homeConfigurations = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };
  config = {
    flake-file.inputs = {
      home-manager = {
        url = "github:LisaScheers/home-manager/agent/nushell-session-environment";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      onepassword-shell-plugins = {
        url = "github:1Password/shell-plugins";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
