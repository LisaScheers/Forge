# Vega's Claude and Codex session files, backed up to Nook every day with
# restic. The repository is encrypted with a password that agenix encrypts to
# Lisa's age key and Vega's host key, so Nook stores only ciphertext. The
# account Vega writes through can only run the SFTP server.
{
  config,
  lib,
  withSystem,
  ...
}: let
  features = config.nixos;
  inherit (config.network) nook;
  pubkeys = config.secrets.pubkeys;
  secrets = ../security/agenix/secrets;
  safePath = lib.types.strMatching "/[A-Za-z0-9._/-]+";
  user = "session-backup";
  directory = "/srv/disks/projects/session-backup";
  # Snapshots are deduplicated, so each day stores only what changed.
  retention = ["--keep-daily" "14" "--keep-weekly" "8" "--keep-monthly" "12"];
  backupScript = pkgs:
    pkgs.writeShellApplication {
      name = "forge-session-backup";
      runtimeInputs = [pkgs.coreutils pkgs.openssh pkgs.restic];
      text = ''
        # Usage: forge-session-backup HOST REPOSITORY PASSWORD_FILE KEY_FILE KNOWN_HOSTS SOURCE...
        host=$1 repository=$2 password=$3 key=$4 known_hosts=$5
        shift 5
        export RESTIC_REPOSITORY="sftp:${user}@$host:$repository" RESTIC_PASSWORD_FILE="$password"
        ssh_command="ssh -i $key -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=30 -o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=yes ${user}@$host -s sftp"
        run_restic() { restic -o sftp.command="$ssh_command" "$@"; }
        run_restic cat config >/dev/null 2>&1 || run_restic init
        sources=()
        for source in "$@"; do
          if [[ -e "$source" ]]; then
            sources+=("$source")
          fi
        done
        run_restic backup --tag sessions "''${sources[@]}"
        run_restic forget --tag sessions ${lib.escapeShellArgs retention} --prune
      '';
    };
in {
  nixos.session-backup-server = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.sessionBackupServer;
  in {
    options.services.sessionBackupServer = {
      directory = lib.mkOption {
        type = safePath;
        description = "Directory holding the restic repository.";
      };
      authorizedKey = lib.mkOption {
        type = lib.types.singleLineStr;
        description = "Public key that may write the repository; it can only run the SFTP server.";
      };
    };
    config = {
      users.users.${user} = {
        isSystemUser = true;
        group = user;
        useDefaultShell = true;
        home = cfg.directory;
        openssh.authorizedKeys.keys = [''restrict,command="${pkgs.openssh}/libexec/sftp-server -d ${cfg.directory}" ${cfg.authorizedKey}''];
      };
      users.groups.${user} = {};
      systemd.tmpfiles.rules = ["d ${cfg.directory} 0700 ${user} ${user} - -"];
    };
  };

  nixos.nook = {
    imports = [features.session-backup-server];
    services.sessionBackupServer = {
      inherit directory;
      authorizedKey = lib.removeSuffix "\n" (builtins.readFile ./vega-session-backup.pub);
    };
  };

  darwin.vega.age.secrets = lib.genAttrs ["session-backup-key" "session-backup-password"] (name: {
    file = secrets + "/vega/${name}.age";
    owner = "lisa";
    mode = "0400";
  });

  home.lisa-vega = {
    config,
    pkgs,
    osConfig,
    ...
  }: let
    home = config.home.homeDirectory;
    knownHosts = pkgs.writeText "session-backup-known-hosts" "${nook.tailscale} ${pubkeys.hosts.nook}\n";
  in {
    launchd.agents.session-backup = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe (backupScript pkgs))
          nook.tailscale
          "${directory}/repo"
          osConfig.age.secrets.session-backup-password.path
          osConfig.age.secrets.session-backup-key.path
          "${knownHosts}"
          "${home}/.claude/projects"
          "${home}/.codex/sessions"
          "${home}/.codex/archived_sessions"
        ];
        StartCalendarInterval = [
          {
            Hour = 4;
            Minute = 45;
          }
        ];
        StandardOutPath = "${home}/Library/Logs/session-backup.log";
        StandardErrorPath = "${home}/Library/Logs/session-backup.log";
        ProcessType = "Background";
        LowPriorityIO = true;
      };
    };
  };

  flake.checks.x86_64-linux.session-backup = withSystem "x86_64-linux" ({pkgs, ...}: let
    # Throwaway keys and password for the test only.
    keys = pkgs.runCommand "session-backup-test-keys" {nativeBuildInputs = [pkgs.openssh];} ''
      mkdir "$out"
      ssh-keygen -q -t ed25519 -N "" -f "$out/client"
      ssh-keygen -q -t ed25519 -N "" -f "$out/host"
      echo test-repository-password > "$out/password"
    '';
    hostKey = builtins.head (builtins.match "([^ ]+ [^ ]+).*" (builtins.readFile "${keys}/host.pub"));
    knownHosts = pkgs.writeText "known-hosts" "server ${hostKey}\n";
    script = lib.getExe (backupScript pkgs);
  in
    pkgs.testers.runNixOSTest {
      name = "session-backup";
      nodes.server = {lib, ...}: {
        imports = [features.session-backup-server];
        services.sessionBackupServer = {
          directory = "/srv/session-backup";
          authorizedKey = lib.removeSuffix "\n" (builtins.readFile "${keys}/client.pub");
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
      nodes.client = {
        environment.systemPackages = [pkgs.restic];
        system.stateVersion = "26.05";
      };
      testScript = ''
        start_all()
        server.wait_for_unit("sshd.service")
        client.copy_from_host("${keys}/client", "/root/key")
        client.succeed("chmod 0600 /root/key")
        client.succeed("mkdir -p /root/.claude/projects/p /root/.codex/sessions && echo plaintext-marker-1 > /root/.claude/projects/p/a.jsonl && echo codex-1 > /root/.codex/sessions/b.jsonl")
        backup = "${script} server /srv/session-backup/repo ${keys}/password /root/key ${knownHosts} /root/.claude/projects /root/.codex/sessions /root/.codex/archived_sessions"
        restic = "RESTIC_PASSWORD_FILE=${keys}/password restic -r sftp:session-backup@server:/srv/session-backup/repo -o sftp.command='ssh -i /root/key -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes session-backup@server -s sftp'"

        with subtest("the first run creates the repository and backs up what exists"):
            client.succeed(backup)
            client.succeed(f"{restic} restore latest --target /root/restore")
            assert client.succeed("cat /root/restore/root/.claude/projects/p/a.jsonl").strip() == "plaintext-marker-1"
            assert client.succeed("cat /root/restore/root/.codex/sessions/b.jsonl").strip() == "codex-1"

        with subtest("Nook holds only ciphertext"):
            server.fail("grep -r plaintext-marker /srv/session-backup")

        with subtest("later runs add snapshots of what changed"):
            client.succeed("echo plaintext-marker-2 >> /root/.claude/projects/p/a.jsonl")
            client.succeed(backup)
            assert client.succeed(f"{restic} snapshots --json | grep -o '\"short_id\"' | wc -l").strip() == "2"

        with subtest("the key can only run the SFTP server"):
            output = client.succeed("timeout 20 ssh -i /root/key -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes -o BatchMode=yes session-backup@server id < /dev/null || true")
            assert "uid=" not in output, output
      '';
    });
}
