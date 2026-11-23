{
  config,
  lib,
  withSystem,
  ...
}: let
  features = config.nixos;
  hosts = config.flake.nixosConfigurations;
  backupAt = hosts.nook.config.services.cogneeBackup.startAt;
  copyAt = hosts.atlas.config.services.cogneeBackupPull.startAt;
in {
  perSystem = {pkgs, ...}: {
    checks.cognee-backup-schedule = let
      inOrder = backupAt == "*-*-* 03:15:00 UTC" && copyAt == "*-*-* 04:15:00 UTC";
    in
      assert lib.assertMsg inOrder "Nook's Cognee backup must run at 03:15 UTC and Atlas's copy at 04:15 UTC; got ${backupAt} and ${copyAt}";
        pkgs.runCommand "cognee-backup-schedule" {} ''touch "$out"'';
  };

  flake.checks.x86_64-linux.cognee-backup = withSystem "x86_64-linux" ({pkgs, ...}: let
    # Throwaway keys for the test only: the puller's SSH key, the source's host
    # key and the age identity that stands in for Lisa's.
    keys = pkgs.runCommand "cognee-backup-test-keys" {nativeBuildInputs = [pkgs.age pkgs.openssh];} ''
      mkdir "$out"
      ssh-keygen -q -t ed25519 -N "" -f "$out/client"
      ssh-keygen -q -t ed25519 -N "" -f "$out/host"
      age-keygen -o "$out/identity" 2>/dev/null
      age-keygen -y "$out/identity" > "$out/recipient"
    '';
    hostKey = builtins.head (builtins.match "([^ ]+ [^ ]+).*" (builtins.readFile "${keys}/host.pub"));
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
          authorizedKey = lib.removeSuffix "\n" (builtins.readFile "${keys}/client.pub");
        };
        # Stands in for the Cognee containers that write the state.
        systemd.services.cognee-writer = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        };
        services.openssh = {
          enable = true;
          hostKeys = [];
          extraConfig = "HostKey /etc/ssh/test_host_key";
        };
        environment.etc."ssh/test_host_key" = {
          source = "${keys}/host";
          mode = "0600";
        };
        system.stateVersion = "26.05";
      };
      nodes.puller = {
        imports = [features.cognee-backup-pull];
        services.cogneeBackupPull = {
          host = "source";
          inherit hostKey;
          keyFile = "/etc/backup-pull-key";
          keepDays = 3;
        };
        # Atlas's clock may differ, so copies must be dated in UTC regardless.
        time.timeZone = "Europe/Brussels";
        environment.etc."backup-pull-key" = {
          source = "${keys}/client";
          mode = "0600";
        };
        environment.systemPackages = [pkgs.age pkgs.zstd];
        system.stateVersion = "26.05";
      };
      testScript = ''
        start_all()
        source.wait_for_unit("sshd.service")
        source.wait_for_unit("cognee-writer.service")
        source.succeed("mkdir -p /srv/cognee/system /srv/cognee/data /srv/cognee/cache && echo graph > /srv/cognee/system/graph.db && echo email > /srv/cognee/data/chunk && echo skip > /srv/cognee/cache/x")

        with subtest("the backup stops the writers, encrypts the state and starts them again"):
            source.succeed("systemctl start cognee-backup.service")
            source.wait_for_unit("cognee-writer.service")
            assert source.succeed("journalctl -u cognee-writer.service | grep -c 'Stopped'").strip() != "0"
            source.succeed("head -c 21 /srv/cognee-backup/cognee.tar.zst.age | grep -q age-encryption.org/v1")
            source.fail("ls /srv/cognee-backup/*.part")

        with subtest("the off-site copy is ciphertext that only the age identity opens"):
            puller.succeed("systemctl start cognee-backup-pull.service")
            copy = "/var/backups/cognee/cognee-$(date -u +%F).tar.zst.age"
            puller.fail(f"zstd -t {copy}")
            puller.copy_from_host("${keys}/identity", "/root/identity")
            listing = puller.succeed(f"age -d -i /root/identity {copy} | zstd -dc | tar -tf -")
            assert "system/graph.db" in listing and "data/chunk" in listing and "cache" not in listing, listing
            assert puller.succeed(f"age -d -i /root/identity {copy} | zstd -dc | tar -xOf - system/graph.db").strip() == "graph"

        with subtest("the key can only read the archive"):
            puller.succeed("install -m 0600 /etc/backup-pull-key /root/key")
            ssh = "ssh -i /root/key -o BatchMode=yes -o StrictHostKeyChecking=no cognee-backup@source"
            puller.succeed(f"timeout 30 {ssh} id | head -c 21 | grep -q age-encryption.org/v1")
            status, refused = puller.execute(f"timeout 30 {ssh} -N -R 9999:localhost:22 -o ExitOnForwardFailure=yes 2>&1")
            assert status != 0 and "forwarding failed" in refused, refused

        with subtest("a stale or corrupt archive never replaces a good copy"):
            puller.succeed("cp /var/backups/cognee/cognee-$(date -u +%F).tar.zst.age /root/good")
            source.succeed("touch -d '24 hours 45 minutes ago' /srv/cognee-backup/cognee.tar.zst.age")
            puller.fail("systemctl start cognee-backup-pull.service")
            puller.succeed("journalctl -u cognee-backup-pull.service | grep -q 'not today'")
            source.succeed("printf 'not age' > /srv/cognee-backup/cognee.tar.zst.age")
            puller.fail("systemctl start cognee-backup-pull.service")
            puller.succeed("cmp /root/good /var/backups/cognee/cognee-$(date -u +%F).tar.zst.age")
            puller.fail("ls /var/backups/cognee/*.part")

        with subtest("copies older than keepDays are pruned"):
            source.succeed("systemctl start cognee-backup.service")
            puller.succeed("cd /var/backups/cognee && for age in 3 4; do cp cognee-$(date -u +%F).tar.zst.age cognee-$(date -u -d \"$age days ago\" +%F).tar.zst.age; done")
            puller.succeed("systemctl start cognee-backup-pull.service")
            puller.succeed("test -f /var/backups/cognee/cognee-$(date -u -d '3 days ago' +%F).tar.zst.age")
            puller.fail("test -f /var/backups/cognee/cognee-$(date -u -d '4 days ago' +%F).tar.zst.age")
      '';
    });
}
