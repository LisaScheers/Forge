{
  config,
  inputs,
  lib,
  ...
}: let
  # Each host module sets deploy.hosts.<host>; its platform comes from its own
  # configuration, so it is declared only once.
  hosts = config.deploy.hosts;
  outputOf = host:
    if config.flake.darwinConfigurations ? ${host}
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

  flake.deploy = deploy;

  flake.deploySystems = lib.mapAttrs (host: _: systemOf host) hosts;
  flake.checks = lib.mkMerge (lib.mapAttrsToList (host: _: {${systemOf host} = hostChecks host;}) hosts);
  ci.targets =
    lib.mapAttrsToList (host: _: {
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
    apps = lib.optionalAttrs (builtins.elem system ["aarch64-darwin" "aarch64-linux" "x86_64-linux"]) {
      deploy = {
        type = "app";
        program = lib.getExe deployPackage;
      };
    };
  };
}
