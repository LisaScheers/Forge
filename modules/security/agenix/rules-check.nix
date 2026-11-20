{
  config,
  lib,
  ...
}: let
  root = toString ./.;
  # Paths as rule keys spell them: relative to this directory.
  relative = path: lib.removePrefix "${root}/" (toString path);
  hosts = config.flake.nixosConfigurations // config.flake.darwinConfigurations;
  # Secret files, relative to this directory, that each host decrypts.
  secretsOf = host: map (secret: relative secret.file) (lib.attrValues hosts.${host}.config.age.secrets);
  consumed = lib.unique (lib.concatMap secretsOf (builtins.attrNames hosts));
  # A rule's host recipients must be exactly the hosts that decrypt the file,
  # so no host can read a secret it does not use.
  hostKeys = config.secrets.pubkeys.hosts;
  keyOf = host: hostKeys.${host} or "missing host key for ${host}";
  readers = file: lib.sort lib.lessThan (map keyOf (lib.filter (host: builtins.elem file (secretsOf host)) (builtins.attrNames hosts)));
  hostRecipients = file: lib.sort lib.lessThan (lib.filter (key: builtins.elem key (lib.attrValues hostKeys)) config.flake.agenixRules.${file}.publicKeys);
  overshared = lib.filter (file: builtins.elem file consumed && hostRecipients file != readers file) rules;
  rules = builtins.attrNames config.flake.agenixRules;
  # Encrypted files on disk, relative to this directory.
  files = map relative (lib.filter (lib.hasSuffix ".age") (map toString (lib.filesystem.listFilesRecursive ./secrets)));
  unused = lib.subtractLists consumed rules;
  unruled = lib.subtractLists rules (lib.unique (consumed ++ files));
in {
  perSystem = {pkgs, ...}: {
    checks.agenix-rules = assert lib.assertMsg (unused == []) "agenix rules without a consuming host: ${toString unused}";
    assert lib.assertMsg (unruled == []) "secret files or declared secrets without an agenix rule: ${toString unruled}";
    assert lib.assertMsg (overshared == []) "agenix rules whose host recipients differ from the hosts that decrypt them: ${toString overshared}";
      pkgs.runCommand "agenix-rules" {} ''
        touch "$out"
      '';
  };
}
