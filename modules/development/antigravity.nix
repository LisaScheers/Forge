{ inputs, ... }: {
  overlays.antigravity-cli = final: _prev: {
    antigravity-cli = inputs.antigravity-cli.packages.${final.stdenv.hostPlatform.system}.default;
  };
  flake-file.inputs.antigravity-cli = {
    url = "github:selfhost-it/antigravity-cli-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  home.lisa-vega = {
    programs.antigravity-cli = {
      enable = true;
      mutableSettings = true;
      settings = {
        allowNonWorkspaceAccess = true;
        enableTelemetry = false;
        model = "Gemini 3.7 Flash (High)";
        permissions = {
          allow = [
            "command(git worktree)"
          ];
        };
      };
    };
  };
}
