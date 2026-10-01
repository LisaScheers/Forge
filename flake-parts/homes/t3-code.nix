{inputs, ...}: {
  forge.modules.homeManager.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  forge.modules.homeManager."lisa@nook" = {pkgs, ...}: {
    services.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
      # The prebuilt package now extracts the native executable directly;
      # retain its NixOS runtime patching without the obsolete npm override.
      package = inputs.t3-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.t3code-server-nightly.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.autoPatchelfHook];
        buildInputs = (old.buildInputs or []) ++ [pkgs.stdenv.cc.cc.lib];
      });
      host = "0.0.0.0";
      port = 3773;
      dataDirectory = "/srv/disks/projects/projects/.t3code";
      providerPackages = [
        pkgs.codex
      ];
    };
  };
  forge.modules.homeManager."lisa@vega" = {
    programs.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
    };
  };
}
