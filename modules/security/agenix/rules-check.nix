{
  config,
  lib,
  ...
}: let
  root = toString ./.;
  systems = lib.attrValues config.flake.nixosConfigurations ++ lib.attrValues config.flake.darwinConfigurations;
  # Secret files, relative to this directory, that some host decrypts.
  consumed = lib.unique (lib.concatMap (system:
    map (secret: lib.removePrefix "${root}/" (toString secret.file)) (lib.attrValues system.config.age.secrets))
  systems);
  rules = builtins.attrNames config.flake.agenixRules;
  unused = lib.subtractLists consumed rules;
  unruled = lib.subtractLists rules consumed;
in {
  perSystem = {pkgs, ...}: {
    checks.agenix-rules = assert lib.assertMsg (unused == []) "agenix rules without a consuming host: ${toString unused}";
    assert lib.assertMsg (unruled == []) "secrets without an agenix rule: ${toString unruled}";
      pkgs.runCommand "agenix-rules" {} ''
        touch "$out"
      '';
  };
}
