{inputs, ...}: {
  darwin.vega = let
    homebrewTaps = {
      "homebrew/core" = inputs.homebrew-core;
      "homebrew/cask" = inputs.homebrew-cask;
    };
  in {
    imports = [inputs.nix-homebrew.darwinModules.nix-homebrew];
    homebrew = {
      enable = true;
      onActivation.autoUpdate = true;
      onActivation.cleanup = "zap";
      brews = [];
      casks = ["moonlight"];
    };

    nix-homebrew = {
      enable = true;
      user = "lisa";
      taps = homebrewTaps;
      mutableTaps = false;
      enableRosetta = true;
    };
  };
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  flake-file.inputs.homebrew-cask = {
    url = "github:homebrew/homebrew-cask";
    flake = false;
  };

  flake-file.inputs.homebrew-core = {
    url = "github:homebrew/homebrew-core";
    flake = false;
  };
}
