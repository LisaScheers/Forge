{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  flake.checks.x86_64-linux.matrix-volume = pkgs.testers.runNixOSTest {
    name = "matrix-volume";
    nodes.machine = {pkgs, ...}: {
      imports = [config.nixos.matrix-volume];
      matrix.volume = {
        enable = true;
        device = "/dev/disk/by-label/matrix-test";
      };
      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "media.test";
          database.name = "sqlite3";
          enable_registration = true;
          enable_registration_without_verification = true;
          listeners = [
            {
              port = 8008;
              bind_addresses = ["127.0.0.1"];
              type = "http";
              tls = false;
              resources = [{names = ["client"];}];
            }
          ];
        };
      };
      systemd.services.restic-backups-matrix = {
        serviceConfig.Type = "oneshot";
        script = "test -d /var/backup/matrix-coordinated";
      };
      environment.systemPackages = [pkgs.python3 pkgs.curl pkgs.e2fsprogs];
      virtualisation.emptyDiskImages = [512];
      # The VM replaces normal fileSystems with its virtual disk declarations.
      virtualisation.fileSystems."/srv/matrix" = {
        device = "/dev/disk/by-label/matrix-test";
        fsType = "ext4";
        options = ["nofail" "x-systemd.device-timeout=5s"];
      };
      virtualisation.memorySize = 2048;
      system.stateVersion = "26.05";
    };
    testScript = ''
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")

      with subtest("blank storage cannot expose local fallback media"):
          machine.fail("systemctl is-active --quiet matrix-synapse")
          machine.fail("curl -fsS http://127.0.0.1:8008/_matrix/client/versions")
          machine.fail("systemctl start restic-backups-matrix")
          machine.succeed("test -z $(find /var/lib/matrix-synapse/media_store -mindepth 1 -print -quit)")

      with subtest("initialized volume hosts real media and independent recovery data"):
          machine.succeed("mkfs.ext4 -q -L matrix-test /dev/vdb; udevadm settle")
          machine.succeed("systemctl reset-failed; systemctl start srv-matrix.mount")
          machine.succeed("printf '%s\\n' atlas-matrix-volume-v1 >/srv/matrix/.matrix-volume; chmod 0444 /srv/matrix/.matrix-volume")
          try:
              machine.succeed("systemctl start matrix-synapse")
          except Exception:
              print(machine.succeed("journalctl -u matrix-synapse --no-pager; systemctl cat matrix-synapse; ls -ld /srv/matrix; findmnt -nro SOURCE,FSTYPE,FSROOT -M /srv/matrix; findmnt -nro SOURCE,FSTYPE,FSROOT -M /var/lib/matrix-synapse/media_store"))
              raise
          machine.wait_until_succeeds("curl -fsS http://127.0.0.1:8008/_matrix/client/versions")
          machine.succeed("python -B ${./media-test.py} upload")
          machine.succeed("systemctl start restic-backups-matrix")
          machine.succeed("findmnt -rn -M /var/lib/matrix-synapse/media_store -t ext4; findmnt -rn -M /var/backup/matrix-coordinated -t ext4")
          machine.succeed("test $(find /srv/matrix/media_store/local_content -type f | wc -l) -ge 1")
          machine.succeed("printf backup-copy >/var/backup/matrix-coordinated/probe; test ! -e /var/lib/matrix-synapse/media_store/probe")

      with subtest("the volume lifetime stops Synapse and a missing marker blocks recovery"):
          machine.succeed("mv /srv/matrix/.matrix-volume /srv/matrix/.matrix-volume-held; systemctl stop srv-matrix.mount")
          machine.fail("systemctl is-active --quiet matrix-synapse")
          machine.succeed("test -z $(find /var/lib/matrix-synapse/media_store -mindepth 1 -print -quit)")
          machine.fail("systemctl start matrix-synapse")
          machine.fail("systemctl start restic-backups-matrix")
          machine.succeed("systemctl start srv-matrix.mount; mv /srv/matrix/.matrix-volume-held /srv/matrix/.matrix-volume; systemctl reset-failed; systemctl start matrix-synapse")
          machine.wait_until_succeeds("curl -fsS http://127.0.0.1:8008/_matrix/client/versions")
          machine.succeed("python -B ${./media-test.py} download")

      with subtest("declarative mounts recover the same authenticated media after reboot"):
          machine.succeed("cp /run/matrix-media-test.json /var/lib/media-test-state.json")
          machine.reboot()
          machine.wait_for_unit("matrix-synapse.service")
          machine.succeed("cp /var/lib/media-test-state.json /run/matrix-media-test.json")
          machine.succeed("python -B ${./media-test.py} download; systemctl start restic-backups-matrix")
    '';
  };
}
