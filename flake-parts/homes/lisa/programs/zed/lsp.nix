{
  forge.modules.homeManager.lisa = {pkgs, ...}: {
    programs.zed-editor.userSettings.lsp = {
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
            expr = "import (builtins.getFlake (builtins.toString ./.)).inputs.nixpkgs { }   ";
          };
          formatting = {
            command = ["nixfmt"];
          };
          options = {
            home-manager = {
              expr = "(builtins.getFlake (builtins.toString ./.)).homeConfigurations.\"lisa@vega\".options";
            };
            flake-file = {
              expr = "(builtins.getFlake (builtins.toString ./.) ).debug.options.flake-file.type.getSubOptions []";
            };
            "nixos" = {
              expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.atlas.options";
            };
            flake-parts = {
              expr = "(builtins.getFlake (builtins.toString ./.)).debug.options";
            };
            devenv = {
              expr = "{ devenv.shells.default = (builtins.getFlake (builtins.toString ./.)).currentSystem.options.devenv.shells.type.getSubOptions []; }";
            };
          };
        };
      };
    };
  };
}
