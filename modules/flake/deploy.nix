{
  config,
  inputs,
  lib,
  ...
}: let
  # Deployment settings for each host deploy-rs manages. The host's platform
  # comes from its own configuration, so it is declared only once.
  hosts = {
    nook.sshUser = "lisa";
    atlas.sshUser = "lisa";
    asterion.sshUser = "root";
    vega = {
      hostname = "localhost";
      sshUser = "lisa";
      interactiveSudo = true;
    };
  };
  configurationOf = host: config.flake.nixosConfigurations.${host} or config.flake.darwinConfigurations.${host};
  systemOf = host: (configurationOf host).pkgs.stdenv.hostPlatform.system;
  activate = host: let
    system = systemOf host;
    kind =
      if lib.hasSuffix "-darwin" system
      then "darwin"
      else "nixos";
  in
    inputs.deploy-rs.lib.${system}.activate.${kind} (configurationOf host);
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
          path = activate host;
        };
      }
      // lib.optionalAttrs (node ? interactiveSudo) {inherit (node) interactiveSudo;})
    hosts;
  };

  # Per-host deploy-rs checks; scripts/deploy.sh builds them before deploying.
  hostChecks = host: let
    checks = inputs.deploy-rs.lib.${systemOf host}.deployChecks (deploy // {nodes.${host} = deploy.nodes.${host};});
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

  flake.deploySystems = lib.mapAttrs (host: _: systemOf host) hosts;
  flake.checks = lib.mkMerge (lib.mapAttrsToList (host: _: {${systemOf host} = hostChecks host;}) hosts);

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
