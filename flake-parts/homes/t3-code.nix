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
      # The bundled optional dependencies in this lockfile fail npm 12's
      # validation. Use Node 22's npm for installation; the upstream wrapper
      # still runs the same T3 release with Node 24.
      package = inputs.t3-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.t3code-server-nightly.override {
        buildNpmPackage = args:
          pkgs.buildNpmPackage (args // {
            nodejs = pkgs.nodejs_22;
            # The npm release includes a native Linux executable.
            nativeBuildInputs = (args.nativeBuildInputs or []) ++ [pkgs.autoPatchelfHook];
            buildInputs = (args.buildInputs or []) ++ [pkgs.stdenv.cc.cc.lib];
          });
      };
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
