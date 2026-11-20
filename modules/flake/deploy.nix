{
  config,
  inputs,
  lib,
  ...
}: let
  # Each host module sets deploy.hosts.<host>; its platform comes from its own
  # configuration, so it is declared only once.
  hosts = config.deploy.hosts;
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
        hostname =
          if node.hostname != null
          then node.hostname
          else host;
        inherit (node) sshUser;
        profiles.system = {
          user = "root";
          path = activate host;
        };
      }
      // lib.optionalAttrs node.interactiveSudo {inherit (node) interactiveSudo;})
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
