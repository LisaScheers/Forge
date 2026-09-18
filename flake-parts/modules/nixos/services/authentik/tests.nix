{
  config,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  flake.checks.x86_64-linux.authentik = pkgs.testers.runNixOSTest {
    name = "authentik-worker";
    nodes.machine = {
      imports = [config.forge.modules.nixos.services_authentik];
      virtualisation = {
        cores = 2;
        memorySize = 4096;
      };
      services.authentik.settings = {
        secret_key = "isolated-test-only";
        disable_update_check = true;
        disable_startup_analytics = true;
        postgresql.host = "/run/postgresql";
      };
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("authentik.service")
      machine.wait_for_unit("authentik-worker.service")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9000/-/health/ready/")
      machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9001/-/health/ready/")

      worker_query = "SELECT count(*) FROM authentik_tasks_workerstatus WHERE last_seen > NOW() - INTERVAL '1 minute'"
      check_worker = f"sudo -u postgres psql authentik -Atc \"{worker_query}\" | grep -qx 1"
      machine.wait_until_succeeds(check_worker)

      with subtest("worker executes background tasks"):
          task_id = machine.succeed("sudo -u authentik env AUTHENTIK_CONFIG=/etc/authentik/config.yml ak shell -c 'from authentik.core.tasks import clean_expired_models; print(clean_expired_models.send().message_id)'").strip().splitlines()[-1]
          task_query = f"SELECT state FROM authentik_tasks_task WHERE message_id = '{task_id}'"
          machine.wait_until_succeeds(f"sudo -u postgres psql authentik -Atc \"{task_query}\" | grep -qx done")

      with subtest("worker registers again after restart"):
          old_worker = machine.succeed("sudo -u postgres psql authentik -Atc 'SELECT id FROM authentik_tasks_workerstatus ORDER BY last_seen DESC LIMIT 1'").strip()
          machine.succeed("systemctl restart authentik-worker.service")
          machine.wait_until_succeeds("curl -fsS http://127.0.0.1:9001/-/health/ready/")
          new_worker_query = f"SELECT count(*) FROM authentik_tasks_workerstatus WHERE id <> '{old_worker}' AND last_seen > NOW() - INTERVAL '1 minute'"
          machine.wait_until_succeeds(f"sudo -u postgres psql authentik -Atc \"{new_worker_query}\" | grep -qx 1")
    '';
  };
}
