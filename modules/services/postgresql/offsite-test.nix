{
  config,
  withSystem,
  ...
}: let
  features = config.nixos;
in {
  flake.checks.x86_64-linux.postgresql-backup-pull = withSystem "x86_64-linux" ({pkgs, ...}: let
    # Throwaway keys for the test only: the puller's key and the source's host key.
    keys = pkgs.runCommand "postgresql-backup-pull-test-keys" {nativeBuildInputs = [pkgs.openssh];} ''
      mkdir "$out"
      ssh-keygen -q -t ed25519 -N "" -f "$out/client"
      ssh-keygen -q -t ed25519 -N "" -f "$out/host"
    '';
    hostKey = builtins.readFile "${keys}/host.pub";
  in
    pkgs.testers.runNixOSTest {
      name = "postgresql-backup-pull";
      nodes.source = {lib, ...}: {
        imports = [features.postgresql-backup-reader];
        services.postgresqlBackupReader = {
          authorizedKey = lib.removeSuffix "\n" (builtins.readFile "${keys}/client.pub");
          dump = "/var/backup/postgresql/all.sql.zstd";
        };
        users.users.postgres = {
          isSystemUser = true;
          group = "postgres";
          useDefaultShell = true;
          home = "/var/lib/postgresql";
          createHome = true;
        };
        users.groups.postgres = {};
        services.openssh = {
          enable = true;
          hostKeys = [];
          extraConfig = "HostKey /etc/ssh/test_host_key";
        };
        environment.etc."ssh/test_host_key" = {
          source = "${keys}/host";
          mode = "0600";
        };
        environment.systemPackages = [pkgs.zstd];
        system.stateVersion = "26.05";
      };
      nodes.puller = {
        imports = [features.postgresql-backup-pull];
        services.postgresqlBackupPull = {
          host = "source";
          hostKey = builtins.head (builtins.match "([^ ]+ [^ ]+).*" hostKey);
          keyFile = "/etc/backup-pull-key";
          destination = "/srv/backups";
          keepDays = 3;
        };
        environment.etc."backup-pull-key" = {
          source = "${keys}/client";
          mode = "0600";
        };
        environment.systemPackages = [pkgs.zstd];
        system.stateVersion = "26.05";
      };
      testScript = ''
        start_all()
        source.wait_for_unit("sshd.service")
        source.succeed("mkdir -p /var/backup/postgresql && echo 'CREATE TABLE restored ();' | zstd -q -o /var/backup/postgresql/all.sql.zstd && chown -R postgres /var/backup/postgresql && chmod 0600 /var/backup/postgresql/all.sql.zstd")

        with subtest("the dump is copied, verified and dated"):
            puller.succeed("systemctl start postgresql-backup-pull.service")
            assert puller.succeed("zstd -dc /srv/backups/all-$(date +%F).sql.zstd").strip() == "CREATE TABLE restored ();"

        with subtest("the key can only read the dump"):
            puller.succeed("install -m 0600 /etc/backup-pull-key /root/key")
            ssh = "ssh -i /root/key -o BatchMode=yes -o StrictHostKeyChecking=no postgres@source"
            # Whatever command is asked for, the forced command prints the dump.
            assert puller.succeed(f"timeout 30 {ssh} id | zstd -dc").strip() == "CREATE TABLE restored ();"
            # restrict refuses forwarding; a remote forward is refused at login.
            refused = puller.execute(f"timeout 30 {ssh} -N -R 9999:localhost:22 -o ExitOnForwardFailure=yes 2>&1")[1]
            assert "forwarding failed" in refused, refused

        with subtest("a corrupt dump never replaces a good copy"):
            source.succeed("printf 'not zstd' > /var/backup/postgresql/all.sql.zstd")
            puller.fail("systemctl start postgresql-backup-pull.service")
            assert puller.succeed("zstd -dc /srv/backups/all-$(date +%F).sql.zstd").strip() == "CREATE TABLE restored ();"
            puller.fail("ls /srv/backups/*.part")

        with subtest("copies older than keepDays are pruned"):
            source.succeed("echo 'SELECT 1;' | zstd -q -f -o /var/backup/postgresql/all.sql.zstd")
            puller.succeed("cp /srv/backups/all-$(date +%F).sql.zstd /srv/backups/all-2000-01-01.sql.zstd && touch -d '10 days ago' /srv/backups/all-2000-01-01.sql.zstd")
            puller.succeed("systemctl start postgresql-backup-pull.service")
            puller.fail("test -e /srv/backups/all-2000-01-01.sql.zstd")
      '';
    });
}
