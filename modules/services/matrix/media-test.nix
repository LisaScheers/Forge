{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux.extend config.overlays.matrix-synapse;
  testKeys = import (inputs.nixpkgs + "/nixos/tests/ssh-keys.nix") pkgs;
in {
  flake.checks.x86_64-linux.matrix-media = pkgs.testers.runNixOSTest {
    name = "matrix-media-nfs";
    nodes = {
      server = {
        imports = [config.nixos.matrix-media-server];
        matrix.mediaServer = {
          enable = true;
          diskMount = "/srv/test-disk";
          directory = "/srv/test-disk/media";
          address = "192.168.1.3";
          clientAddress = "192.168.1.2";
          interface = "eth1";
          networkUnit = "network-online.target";
          migrationPublicKeys = [testKeys.snakeOilEd25519PublicKey];
        };
        services.openssh.enable = true;
        virtualisation.fileSystems."/srv/test-disk" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = ["size=128M"];
        };
        virtualisation.memorySize = 512;
        system.stateVersion = "26.05";
      };
      client = {pkgs, ...}: {
        imports = [config.nixos.matrix-media-client];
        matrix.remoteMedia = {
          enable = true;
          serverAddress = "192.168.1.3";
          networkUnit = "network-online.target";
          mountTimeout = 5;
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
                resources = [
                  {
                    names = ["client"];
                    compress = false;
                  }
                ];
              }
            ];
          };
        };
        environment.systemPackages = [pkgs.python3 pkgs.curl pkgs.nfs-utils pkgs.rsync pkgs.openssh];
        virtualisation.memorySize = 2048;
        system.stateVersion = "26.05";
      };
      attacker = {pkgs, ...}: {
        environment.systemPackages = [pkgs.nfs-utils];
        virtualisation.memorySize = 256;
        system.stateVersion = "26.05";
      };
    };
    testScript = ''
      import shlex

      start_all()
      try:
          server.wait_for_unit("nfs-server.service")
      except Exception:
          print(server.succeed("systemctl status nfs-server nfs-mountd matrix-media-directory --no-pager || true"))
          print(server.succeed("journalctl -b -u nfs-server -u nfs-mountd -u matrix-media-directory --no-pager"))
          raise
      client.wait_for_unit("matrix-synapse.service")
      client.wait_until_succeeds("curl -fsS http://127.0.0.1:8008/_matrix/client/versions")
      mount_unit = client.succeed("systemd-escape --path --suffix=mount /var/lib/matrix-synapse/media_store").strip()
      automount_unit = mount_unit.removesuffix(".mount") + ".automount"

      with subtest("Synapse stores authenticated media on the NAS"):
          client.succeed("python -B ${./media-test.py} upload")
          server.succeed("test $(find /srv/test-disk/media/local_content -type f | wc -l) -ge 1")
          client.succeed("findmnt -rn -M /var/lib/matrix-synapse/media_store -t nfs4")

      with subtest("unapproved peers cannot mount the export"):
          attacker.succeed("mkdir -p /mnt/denied")
          attacker.fail("timeout 10 mount -t nfs4 -o vers=4.2 192.168.1.3:/ /mnt/denied")
          attacker.fail("mountpoint -q /mnt/denied")

      with subtest("restricted rsync copies media and supports an independent backup"):
          client.succeed("install -m 0600 ${testKeys.snakeOilEd25519PrivateKey} /run/media-test-key")
          ssh = "ssh -i /run/media-test-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
          client.succeed("mkdir /run/media-source /run/media-backup; printf media-test >/run/media-source/probe")
          client.succeed("rsync -a --no-owner --no-group -e " + shlex.quote(ssh) + " /run/media-source/ matrix-media@192.168.1.3:.")
          client.succeed("rsync -a --delete -e " + shlex.quote(ssh) + " matrix-media@192.168.1.3:. /run/media-backup/")
          client.succeed("cmp /run/media-source/probe /run/media-backup/probe")
          client.fail(ssh + " matrix-media@192.168.1.3 id")
          client.fail("rsync -a --delete -e " + shlex.quote(ssh) + " /run/media-source/ matrix-media@192.168.1.3:.")
          client.succeed("rm /var/lib/matrix-synapse/media_store/probe")

      with subtest("an unavailable NAS cannot create local replacement media"):
          client.succeed("systemctl stop matrix-synapse " + shlex.quote(mount_unit) + " " + shlex.quote(automount_unit))
          client.succeed("test -z $(find /var/lib/matrix-synapse/media_store -mindepth 1 -print -quit)")
          server.succeed("systemctl stop nfs-server")
          client.succeed("systemctl start --no-block matrix-synapse")
          client.fail("curl --max-time 5 -fsS http://127.0.0.1:8008/_matrix/client/versions")
          client.sleep(7)
          client.fail("systemctl is-active --quiet matrix-synapse")

      with subtest("mount retries recover and keep the same media URL"):
          server.succeed("systemctl start nfs-server")
          client.wait_until_succeeds("systemctl is-active --quiet matrix-synapse", timeout=180)
          client.succeed("python -B ${./media-test.py} download")

      with subtest("the disk mount controls the export lifetime"):
          disk_unit = server.succeed("systemd-escape --path --suffix=mount /srv/test-disk").strip()
          server.succeed("systemctl stop " + shlex.quote(disk_unit))
          server.fail("systemctl is-active --quiet nfs-server")
          server.succeed("test ! -e /srv/test-disk/media")
    '';
  };
}
