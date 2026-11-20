{
  config,
  inputs,
  lib,
  ...
}: let
  # Each host module sets deploy.hosts.<host>; its platform comes from its own
  # configuration, so it is declared only once.
  hosts = config.deploy.hosts;
  darwinConfigurations = config.flake.darwinConfigurations or {};
  nixosConfigurations = config.flake.nixosConfigurations or {};
  outputOf = host:
    assert lib.assertMsg (darwinConfigurations ? ${host} != nixosConfigurations ? ${host})
    "deploy.hosts.${host} needs exactly one NixOS or nix-darwin configuration of that name";
      if darwinConfigurations ? ${host}
      then {
        kind = "darwin";
        collection = "darwinConfigurations";
        toplevel = ["system"];
      }
      else {
        kind = "nixos";
        collection = "nixosConfigurations";
        toplevel = ["config" "system" "build" "toplevel"];
      };
  configurationOf = host: config.flake.${(outputOf host).collection}.${host};
  systemOf = host: (configurationOf host).pkgs.stdenv.hostPlatform.system;
  activate = host: inputs.deploy-rs.lib.${systemOf host}.activate.${(outputOf host).kind} (configurationOf host);
  deploy = {
    autoRollback = true;
    magicRollback = true;
    activationTimeout = 600;
    confirmTimeout = 60;

    nodes = lib.mapAttrs (host: node:
      {
        inherit (node) hostname sshUser;
        profiles.system = {
          user = "root";
          path = activate host;
        };
      }
      // lib.optionalAttrs node.interactiveSudo {inherit (node) interactiveSudo;})
    hosts;
  };

  # Per-host closure and deploy-rs checks; scripts/deploy.sh builds them before
  # deploying, and the host's CI job builds them together.
  hostChecks = host: let
    checks = inputs.deploy-rs.lib.${systemOf host}.deployChecks (deploy // {nodes.${host} = deploy.nodes.${host};});
  in {
    ${host} = lib.getAttrFromPath (outputOf host).toplevel (configurationOf host);
    "deploy-schema-${host}" = checks.deploy-schema;
    "deploy-activate-${host}" = checks.deploy-activate;
  };
in {
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # scripts/deploy.sh pauses Atlas's updater through the `atlas` SSH alias, the
  # same name deploy-rs connects to.
  flake.deploy = assert lib.assertMsg ((hosts.atlas.hostname or "atlas") == "atlas")
  "deploy.hosts.atlas.hostname must stay \"atlas\": scripts/deploy.sh reaches Atlas's updater through that SSH alias"; deploy;

  flake.deploySystems = lib.mapAttrs (host: _: systemOf host) hosts;
  flake.checks = lib.mkMerge (lib.mapAttrsToList (host: _: {${systemOf host} = hostChecks host;}) hosts);
  ci.targets =
    lib.mapAttrsToList (host: _: {
      # For example nixosConfigurations."atlas".config.system.build.toplevel.
      target = lib.concatStringsSep "." ([(outputOf host).collection ''"${host}"''] ++ (outputOf host).toplevel);
      system = systemOf host;
      checks = builtins.attrNames (hostChecks host);
    })
    hosts;

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
    apps = lib.optionalAttrs (inputs.deploy-rs.packages ? ${system}) {
      deploy = {
        type = "app";
        program = lib.getExe deployPackage;
      };
    };
  };
}
