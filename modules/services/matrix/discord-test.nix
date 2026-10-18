{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux.extend config.overlays.matrix-synapse;
in {
  flake.checks.x86_64-linux.discord-bridge = pkgs.testers.runNixOSTest {
    name = "discord-bridge-foundation";
    nodes.machine = {pkgs, ...}: {
      imports = [config.nixos.matrix];
      networking.domain = "bridge.test";
      matrix = {
        enable = false;
        discord = {
          enable = true;
          initialBackfillLimit = 100;
          federateRooms = false;
          environmentFile = toString (pkgs.writeText "discord-test-env" ''
            DISCORD_PROVISIONING_SECRET=isolated-test-only
          '');
        };
      };
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_18;
      };
      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "bridge.test";
          database.name = "sqlite3";
          listeners = [
            {
              port = 8008;
              bind_addresses = ["::1"];
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
      environment.systemPackages = [pkgs.curl pkgs.yq];
      virtualisation.memorySize = 2048;
      system.stateVersion = "26.05";
    };
    testScript = ''
      import json

      start_all()
      machine.wait_for_unit("postgresql.service")
      machine.wait_for_unit("matrix-synapse.service")
      machine.wait_for_unit("mautrix-discord.service")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:29334/_matrix/mau/live")
      machine.wait_until_succeeds("curl -fsS http://[::1]:8008/_matrix/client/versions")

      with subtest("provisioning is authenticated and loopback-only"):
          machine.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:29334/_matrix/provision/v1/ping) = 401")
          machine.succeed("curl -fsS -H 'Authorization: Bearer isolated-test-only' 'http://127.0.0.1:29334/_matrix/provision/v1/ping?user_id=%40sec-hive-relay%3Abridge.test'")
          machine.succeed("ss -ltn | grep -F '127.0.0.1:29334'")
          machine.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):29334'")

      with subtest("PostgreSQL bridge schema is initialized without creating portals"):
          machine.succeed("sudo -u mautrix-discord psql -d mautrix-discord -Atc 'SELECT count(*) FROM portal' | grep -qx 0")

      with subtest("registration and tokens survive service regeneration"):
          before = json.loads(machine.succeed("yq -j . /var/lib/mautrix-discord/discord-registration.yaml"))
          machine.succeed("systemctl stop mautrix-discord matrix-synapse")
          machine.succeed("systemctl restart mautrix-discord-registration")
          machine.succeed("systemctl start matrix-synapse mautrix-discord")
          machine.wait_until_succeeds("curl -fsS http://127.0.0.1:29334/_matrix/mau/live")
          after = json.loads(machine.succeed("yq -j . /var/lib/mautrix-discord/discord-registration.yaml"))
          assert before["as_token"] == after["as_token"]
          assert before["hs_token"] == after["hs_token"]
    '';
  };
}
