{
  config,
  lib,
  withSystem,
  ...
}: let
  features = config.nixos;
  backupAt = config.flake.nixosConfigurations.nook.config.services.cogneeBackup.startAt;
in {
  perSystem = {pkgs, ...}: {
    checks.cognee-backup-schedule = assert lib.assertMsg (backupAt == "*-*-* 03:15:00 UTC") "Nook's Cognee backup must run at 03:15 UTC; got ${backupAt}";
      pkgs.runCommand "cognee-backup-schedule" {} ''touch "$out"'';
  };

  flake.checks.x86_64-linux.cognee-backup = withSystem "x86_64-linux" ({pkgs, ...}: let
    # A throwaway age identity that stands in for Lisa's.
    keys = pkgs.runCommand "cognee-backup-test-keys" {nativeBuildInputs = [pkgs.age];} ''
      mkdir "$out"
      age-keygen -o "$out/identity" 2>/dev/null
      age-keygen -y "$out/identity" > "$out/recipient"
    '';
  in
    pkgs.testers.runNixOSTest {
      name = "cognee-backup";
      nodes.source = {lib, ...}: {
        imports = [features.cognee-backup];
        services.cogneeBackup = {
          storageRoot = "/srv/cognee";
          paths = ["system" "data"];
          stopUnits = ["cognee-writer.service"];
          recipient = lib.removeSuffix "\n" (builtins.readFile "${keys}/recipient");
          destination = "/srv/cognee-backup";
        };
        # Stands in for the Cognee containers that write the state.
        systemd.services.cognee-writer = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        };
        environment.systemPackages = [pkgs.age pkgs.zstd];
        system.stateVersion = "26.05";
      };
      testScript = ''
        source.wait_for_unit("cognee-writer.service")
        source.succeed("mkdir -p /srv/cognee/system /srv/cognee/data /srv/cognee/cache && echo graph > /srv/cognee/system/graph.db && echo email > /srv/cognee/data/chunk && echo skip > /srv/cognee/cache/x")

        with subtest("the backup stops the writers, encrypts the state and starts them again"):
            source.succeed("systemctl start cognee-backup.service")
            source.wait_for_unit("cognee-writer.service")
            assert source.succeed("journalctl -u cognee-writer.service | grep -c 'Stopped'").strip() != "0"
            source.fail("ls /srv/cognee-backup/*.part")
            assert source.succeed("stat -c %a:%U /srv/cognee-backup/cognee.tar.zst.age").strip() == "600:root"

        with subtest("the archive is ciphertext that only the age identity opens"):
            archive = "/srv/cognee-backup/cognee.tar.zst.age"
            source.fail(f"zstd -t {archive}")
            source.copy_from_host("${keys}/identity", "/root/identity")
            listing = source.succeed(f"age -d -i /root/identity {archive} | zstd -dc | tar -tf -")
            assert "system/graph.db" in listing and "data/chunk" in listing and "cache" not in listing, listing
            assert source.succeed(f"age -d -i /root/identity {archive} | zstd -dc | tar -xOf - system/graph.db").strip() == "graph"
      '';
    });
}
