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

  linuxDeploy =
    deploy
    // {
      nodes = {
        inherit (deploy.nodes) nook atlas;
      };
    };

  darwinDeploy =
    deploy
    // {
      nodes = {
        inherit (deploy.nodes) vega;
      };
    };

  asterionDeploy =
    deploy
    // {
      nodes = {
        inherit (deploy.nodes) asterion;
      };
    };

  linuxDeployChecks = inputs.deploy-rs.lib.x86_64-linux.deployChecks linuxDeploy;
  asterionDeployChecks = inputs.deploy-rs.lib.aarch64-linux.deployChecks asterionDeploy;
  darwinDeployChecks = inputs.deploy-rs.lib.aarch64-darwin.deployChecks darwinDeploy;
  nookDeployChecks = inputs.deploy-rs.lib.x86_64-linux.deployChecks (
    deploy
    // {
      nodes = {
        inherit (deploy.nodes) nook;
      };
    }
  );
  atlasDeployChecks = inputs.deploy-rs.lib.x86_64-linux.deployChecks (
    deploy
    // {
      nodes = {
        inherit (deploy.nodes) atlas;
      };
    }
  );
in {
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs/c03082a563c010c03a5c3d5e1507ccd9dd53d341";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.deploy = deploy;

  flake.checks.x86_64-linux =
    linuxDeployChecks
    // {
      deploy-schema-nook = nookDeployChecks.deploy-schema;
      deploy-schema-atlas = atlasDeployChecks.deploy-schema;
      deploy-activate-nook = nookDeployChecks.deploy-activate;
      deploy-activate-atlas = atlasDeployChecks.deploy-activate;
    };
  flake.checks.aarch64-linux =
    asterionDeployChecks
    // {
      deploy-schema-asterion = asterionDeployChecks.deploy-schema;
      deploy-activate-asterion = asterionDeployChecks.deploy-activate;
    };
  flake.checks.aarch64-darwin =
    darwinDeployChecks
    // {
      deploy-schema-vega = darwinDeployChecks.deploy-schema;
      deploy-activate-vega = darwinDeployChecks.deploy-activate;
    };

  perSystem = {system, ...}: {
    apps = lib.optionalAttrs (builtins.elem system ["aarch64-darwin" "aarch64-linux" "x86_64-linux"]) {
      deploy = inputs.deploy-rs.apps.${system}.deploy-rs;
    };
  };
}
