{inputs, ...}: {
  forge.modules.darwin.vega = let
    homebrewTaps = {
      "homebrew/core" = inputs.homebrew-core;
      "homebrew/cask" = inputs.homebrew-cask;
    };
  in {
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
  flake-file.inputs.homebrew-cask = {
    url = "github:homebrew/homebrew-cask";
    flake = false;
  };

  flake-file.inputs.homebrew-core = {
    url = "github:homebrew/homebrew-core";
    flake = false;
  };
}
