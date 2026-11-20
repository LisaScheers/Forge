{
  config,
  inputs,
  lib,
  ...
}: let
  # Each deployable host's system selects its deploy-rs activation, its checks,
  # and the checks scripts/deploy.sh builds (via the deploySystems output).
  hosts = {
    nook = {
      system = "x86_64-linux";
      sshUser = "lisa";
    };
    atlas = {
      system = "x86_64-linux";
      sshUser = "lisa";
    };
    asterion = {
      system = "aarch64-linux";
      sshUser = "root";
    };
    vega = {
      system = "aarch64-darwin";
      hostname = "localhost";
      sshUser = "lisa";
      interactiveSudo = true;
    };
  };
  activate = host: system:
    if lib.hasSuffix "-darwin" system
    then inputs.deploy-rs.lib.${system}.activate.darwin config.flake.darwinConfigurations.${host}
    else inputs.deploy-rs.lib.${system}.activate.nixos config.flake.nixosConfigurations.${host};
  deploy = {
    autoRollback = true;
    magicRollback = true;
    activationTimeout = 600;
    confirmTimeout = 60;

    nodes = lib.mapAttrs (host: node:
      {
        hostname = node.hostname or host;
        inherit (node) sshUser;
        profiles.system = {
          user = "root";
          path = activate host node.system;
        };
      }
      // lib.optionalAttrs (node ? interactiveSudo) {inherit (node) interactiveSudo;})
    hosts;
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

  flake.deploySystems = lib.mapAttrs (_: node: node.system) hosts;
  flake.checks = lib.mkMerge (lib.mapAttrsToList (host: node: {${node.system} = hostChecks node.system host;}) hosts);

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
