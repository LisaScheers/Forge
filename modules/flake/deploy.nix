{
  config,
  inputs,
  lib,
  ...
}: let
  deploy = {
    autoRollback = true;
    magicRollback = true;
    activationTimeout = 600;
    confirmTimeout = 60;

    nodes = {
      nook = {
        hostname = "nook";
        sshUser = "lisa";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.nook;
        };
      };

      atlas = {
        hostname = "atlas";
        sshUser = "lisa";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.atlas;
        };
      };

      asterion = {
        hostname = "asterion";
        sshUser = "root";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.aarch64-linux.activate.nixos config.flake.nixosConfigurations.asterion;
        };
      };

      vega = {
        hostname = "localhost";
        sshUser = "lisa";
        interactiveSudo = true;
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.aarch64-darwin.activate.darwin config.flake.darwinConfigurations.vega;
        };
      };
    };
  };

  # Per-host deploy-rs checks; scripts/deploy.sh builds them before deploying.
  hostChecks = system: host: let
    checks = inputs.deploy-rs.lib.${system}.deployChecks (deploy // {nodes.${host} = deploy.nodes.${host};});
  in {
    "deploy-schema-${host}" = checks.deploy-schema;
    "deploy-activate-${host}" = checks.deploy-activate;
  };
in {
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.deploy = deploy;

  flake.checks.x86_64-linux = hostChecks "x86_64-linux" "nook" // hostChecks "x86_64-linux" "atlas";
  flake.checks.aarch64-linux = hostChecks "aarch64-linux" "asterion";
  flake.checks.aarch64-darwin = hostChecks "aarch64-darwin" "vega";

  perSystem = {system, ...}: let
    deployPackage = inputs.deploy-rs.packages.${system}.deploy-rs.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          # Lix removed the legacy nix-store --serve protocol used by ssh://.
          substituteInPlace src/push.rs \
            --replace-fail '"ssh://{}@{}"' '"ssh-ng://{}@{}"'
        '';
    });
  in {
    apps = lib.optionalAttrs (builtins.elem system ["aarch64-darwin" "aarch64-linux" "x86_64-linux"]) {
      deploy = {
        type = "app";
        program = lib.getExe deployPackage;
      };
    };
  };
}
