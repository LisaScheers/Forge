{
  inputs,
  lib,
  ...
}: let
  profile = marker: {
    options.marker = lib.mkOption {type = lib.types.str;};
    config.marker = marker;
  };
  fixture = inputs.flake-parts.lib.evalFlakeModule {inherit inputs;} {
    imports = [./profiles.nix];
    systems = [];
    nixos.example = profile "nixos";
    darwin.example = profile "darwin";
    home.example = profile "home";
  };
  evaluate = class: module:
    (lib.evalModules {
      inherit class;
      modules = [module];
    }).config.marker;
  valid =
    evaluate "nixos" fixture.config.nixos.example
    == "nixos"
    && evaluate "darwin" fixture.config.darwin.example == "darwin"
    && evaluate "homeManager" fixture.config.home.example == "home"
    && evaluate "homeManager" fixture.config.flake.modules.homeManager.example == "home"
    && !(builtins.tryEval (evaluate "homeManager" fixture.config.nixos.example)).success;
in {
  perSystem = {pkgs, ...}: {
    checks.profiles = assert lib.assertMsg valid "Profiles must preserve their module class and public exports";
      pkgs.runCommand "profile-classes" {} ''
        touch "$out"
      '';
  };
}
