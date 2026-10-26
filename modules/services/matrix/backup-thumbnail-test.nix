{inputs, ...}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  flake.checks.x86_64-linux.matrix-backup-thumbnails = pkgs.testers.runNixOSTest {
    name = "matrix-backup-thumbnails";
    nodes.machine = {pkgs, ...}: {
      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "backup.test";
          database.name = "sqlite3";
          enable_registration = true;
          enable_registration_without_verification = true;
          dynamic_thumbnails = false;
          listeners = [{
            port = 8008;
            bind_addresses = ["127.0.0.1"];
            type = "http";
            tls = false;
            resources = [{names = ["client"];}];
          }];
        };
      };
      systemd.services.matrix-synapse.serviceConfig.PrivateNetwork = true;
      environment.systemPackages = [pkgs.python3 pkgs.util-linux];
      virtualisation.memorySize = 2048;
      system.stateVersion = "26.05";
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("matrix-synapse.service")
      machine.succeed("nsenter --net=/proc/$(systemctl show matrix-synapse -p MainPID --value)/ns/net python -B ${./backup-thumbnail-test.py}")
    '';
  };
}
