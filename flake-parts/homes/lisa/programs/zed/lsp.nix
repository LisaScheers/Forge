{pkgs}: let
  flakePath = "/private/etc/nix-darwin";
in {
  nil = {
    binary = {
      path = pkgs.nil + "/bin/nil";
    };
    settings = {
      formatting = {
        command = ["alejandra"];
      };
      diagnostics = {
        ignored = [
          "unused_binding"
        ];
      };
      nix = {
        binary = pkgs.nix + "/bin/nix";
        maxMemoryMB = 2560;
        flake = {
          autoArchive = true;
          autoEvalInputs = true;
          nixpkgsInputName = "nixpkgs";
        };
      };
    };
  };
  nixd = {
    settings = {
      nixpkgs = {
        expr = "import (builtins.getFlake \"" + flakePath + "\").inputs.nixpkgs { }   ";
      };
      formatting = {
        command = ["nixfmt"];
      };
      options = {
        nixos = {
          expr = "(builtins.getFlake \"" + flakePath + "\").nixosConfigurations.atlas.options";
        };
        home-manager = {
          expr = "(builtins.getFlake \"" + flakePath + "\").homeConfigurations.\"lisa@vega\".options";
        };
        nix-darwin = {
          expr = "(builtins.getFlake \"" + flakePath + "\").darwinConfigurations.vega.options";
        };
        flake-parts = {
          expr = "(builtins.getFlake \"" + flakePath + "\").debug.options";
        };
        flake-parts2 = {
          expr = "(builtins.getFlake \"" + flakePath + "\").currentSystem.options";
        };
      };
    };
  };
}
