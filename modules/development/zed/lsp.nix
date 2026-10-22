{inputs, ...}: {
  home.lisa = {pkgs, ...}: {
    programs.zed-editor.userSettings.languages.Nix.language_servers = ["nixd" "!nil" "..."];
    programs.zed-editor.userSettings.lsp = {
      discord_presence.initialization_options = {
        application_id = "1263505205522337886";
        state = "Working on {filename}";
        details = "In {workspace}";
      };
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
        settings = inputs.self.lib.nixdSettings pkgs;
        binary = {
          path = "${pkgs.nixd}/bin/nixd";
          arguments = [];
        };
      };
    };
  };
}
