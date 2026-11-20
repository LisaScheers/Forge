{
  config,
  lib,
  ...
}: let
  root = toString ./.;
  # Paths as rule keys spell them: relative to this directory.
  relative = path: lib.removePrefix "${root}/" (toString path);
  hosts = config.flake.nixosConfigurations // config.flake.darwinConfigurations;

  # Every rule this check enforces, over plain data so the fixtures below run
  # the same code. Each entry lists the offending files or hosts.
  problemsIn = {
    rules,
    secretsByHost,
    files,
    pubkeys,
  }: let
    ruled = builtins.attrNames rules;
    consumed = lib.unique (lib.concatLists (lib.attrValues secretsByHost));
    readersOf = file: builtins.attrNames (lib.filterAttrs (_: secrets: builtins.elem file secrets) secretsByHost);
    keysOf = file: rules.${file}.publicKeys;
    hostsIn = file: builtins.attrNames (lib.filterAttrs (_: key: builtins.elem key (keysOf file)) pubkeys.hosts);
    knownKeys = lib.attrValues pubkeys.users ++ lib.attrValues pubkeys.hosts;
    # secrets/<host>/ holds what exactly one host reads; secrets/shared/ what several read.
    directoryOf = file: builtins.elemAt (lib.splitString "/" file) 1;
    consumedRules = lib.filter (file: builtins.elem file consumed) ruled;
  in {
    "rules without a consuming host" = lib.subtractLists consumed ruled;
    "secret files or declared secrets without a rule" = lib.subtractLists ruled (lib.unique (consumed ++ files));
    "hosts that decrypt secrets but have no host key" =
      builtins.attrNames (lib.filterAttrs (host: secrets: secrets != [] && !(pubkeys.hosts ? ${host})) secretsByHost);
    "rules with a key that is neither a user nor a host key" = lib.filter (file: lib.any (key: !builtins.elem key knownKeys) (keysOf file)) ruled;
    "rules without Lisa's key" = lib.filter (file: !builtins.elem pubkeys.users.lisa (keysOf file)) ruled;
    # No host may read a secret it does not use, and every reader must be able to.
    "rules whose hosts differ from the hosts that decrypt the file" = lib.filter (file: hostsIn file != readersOf file) consumedRules;
    "host-directory secrets not read by exactly that host" =
      lib.filter (file: directoryOf file != "shared" && readersOf file != [(directoryOf file)]) consumedRules;
    "shared secrets read by fewer than two hosts" =
      lib.filter (file: directoryOf file == "shared" && builtins.length (readersOf file) < 2) consumedRules;
  };

  actual = problemsIn {
    rules = config.flake.agenixRules;
    secretsByHost = lib.mapAttrs (_: host: map (secret: relative secret.file) (lib.attrValues host.config.age.secrets)) hosts;
    files = map relative (lib.filter (lib.hasSuffix ".age") (map toString (lib.filesystem.listFilesRecursive ./secrets)));
    inherit (config.secrets) pubkeys;
  };
  failures = lib.filterAttrs (_: offenders: offenders != []) actual;

  # A consistent fixture, then one break per rule; each must be reported.
  fixture = {
    rules = {
      "secrets/a/one.age".publicKeys = ["L" "A"];
      "secrets/shared/two.age".publicKeys = ["L" "A" "B"];
    };
    secretsByHost = {
      a = ["secrets/a/one.age" "secrets/shared/two.age"];
      b = ["secrets/shared/two.age"];
    };
    files = ["secrets/a/one.age" "secrets/shared/two.age"];
    pubkeys = {
      users.lisa = "L";
      hosts = {
        a = "A";
        b = "B";
      };
    };
  };
  reports = rule: change: (problemsIn (lib.recursiveUpdate fixture change)).${rule} != [];
  fixtureHolds =
    lib.all (offenders: offenders == []) (lib.attrValues (problemsIn fixture))
    && reports "rules without a consuming host" {rules."secrets/a/three.age".publicKeys = ["L" "A"];}
    && reports "secret files or declared secrets without a rule" {files = fixture.files ++ ["secrets/a/stray.age"];}
    && reports "hosts that decrypt secrets but have no host key" {secretsByHost.c = ["secrets/shared/two.age"];}
    && reports "rules with a key that is neither a user nor a host key" {rules."secrets/a/one.age".publicKeys = ["L" "A" "OLD"];}
    && reports "rules without Lisa's key" {rules."secrets/a/one.age".publicKeys = ["A"];}
    && reports "rules whose hosts differ from the hosts that decrypt the file" {rules."secrets/a/one.age".publicKeys = ["L" "A" "B"];}
    && reports "rules whose hosts differ from the hosts that decrypt the file" {rules."secrets/shared/two.age".publicKeys = ["L" "A"];}
    && reports "host-directory secrets not read by exactly that host" {secretsByHost.b = ["secrets/shared/two.age" "secrets/a/one.age"];}
    && reports "shared secrets read by fewer than two hosts" {secretsByHost.b = [];};
in {
  perSystem = {pkgs, ...}: {
    checks.agenix-rules = assert lib.assertMsg fixtureHolds "agenix-rules: a fixture rule is no longer detected";
    assert lib.assertMsg (failures == {})
    "agenix-rules: ${lib.concatStringsSep "; " (lib.mapAttrsToList (rule: offenders: "${rule}: ${toString offenders}") failures)}";
      pkgs.runCommand "agenix-rules" {} ''
        touch "$out"
      '';
  };
}
