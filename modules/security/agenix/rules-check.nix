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
  # Encrypted files on disk, relative to this directory.
  files = map (path: lib.removePrefix "${root}/" (toString path)) (lib.filter (path: lib.hasSuffix ".age" (toString path)) (lib.filesystem.listFilesRecursive ./secrets));
  unused = lib.subtractLists consumed rules;
  unruled = lib.subtractLists rules (lib.unique (consumed ++ files));
in {
  perSystem = {pkgs, ...}: {
    checks.agenix-rules = assert lib.assertMsg (unused == []) "agenix rules without a consuming host: ${toString unused}";
    assert lib.assertMsg (unruled == []) "secret files or declared secrets without an agenix rule: ${toString unruled}";
      pkgs.runCommand "agenix-rules" {} ''
        touch "$out"
      '';
  };
}
