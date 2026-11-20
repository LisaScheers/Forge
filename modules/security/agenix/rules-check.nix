{
  config,
  lib,
  ...
}: let
  root = toString ./.;
  # Paths as rule keys spell them: relative to this directory.
  relative = path: lib.removePrefix "${root}/" (toString path);
  systems = lib.attrValues config.flake.nixosConfigurations ++ lib.attrValues config.flake.darwinConfigurations;
  # Secret files, relative to this directory, that some host decrypts.
  consumed = lib.unique (lib.concatMap (system:
    map (secret: relative secret.file) (lib.attrValues system.config.age.secrets))
  systems);
  rules = builtins.attrNames config.flake.agenixRules;
  # Encrypted files on disk, relative to this directory.
  files = map relative (lib.filter (lib.hasSuffix ".age") (map toString (lib.filesystem.listFilesRecursive ./secrets)));
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
