{
  config,
  inputs,
  lib,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux.extend (lib.composeManyExtensions (lib.attrValues config.overlays));
  fixtureToken = digit: lib.concatStrings (lib.replicate 64 digit);
in {
  flake.checks.x86_64-linux.pluralmatrix = pkgs.testers.runNixOSTest {
    name = "pluralmatrix-integration";
    nodes.machine = {
      lib,
      pkgs,
      ...
    }: {
      imports = [config.nixos.matrix];
      networking.domain = "plural.test";
      matrix = {
        enable = false;
        plural = {
          enable = true;
          allowedRooms = ["!fixture:plural.test"];
          secretsFile = toString (pkgs.writeText "plural-test-secrets" (builtins.toJSON {
            as_token = fixtureToken "1";
            hs_token = fixtureToken "2";
            jwt_secret = fixtureToken "3";
            gatekeeper_secret = fixtureToken "4";
            avatar_proxy_key = fixtureToken "5";
          }));
        };
      };
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_18;
      };
      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "plural.test";
          database.name = "sqlite3";
          enable_registration = true;
          enable_registration_without_verification = true;
          trusted_key_servers = [];
          rc_message = {
            per_second = 100;
            burst_count = 100;
          };
          rc_registration = {
            per_second = 100;
            burst_count = 100;
          };
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
      systemd.services.pluralmatrix.serviceConfig = {
        Restart = lib.mkForce "no";
        EnvironmentFile = lib.mkForce ["/var/lib/pluralmatrix-registration/environment" "-/run/pluralmatrix-test-environment"];
      };
      environment.systemPackages = [pkgs.python3 pkgs.curl pkgs.postgresql_18 pkgs.util-linux];
      virtualisation.memorySize = 4096;
      system.stateVersion = "26.05";
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("postgresql.service")
      machine.wait_for_unit("matrix-synapse.service")
      machine.wait_for_unit("pluralmatrix.service")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:29335/health", timeout=180)
      machine.succeed("python3 ${./plural-test.py}", timeout=300)
      machine.succeed("ss -ltn | grep -F '127.0.0.1:29335'")
      machine.succeed("ss -ltn | grep -F '127.0.0.1:29336'")
      machine.succeed("ss -ltn | grep -F '127.0.0.1:29337'")
      machine.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):2933[567]'")
    '';
  };
}
