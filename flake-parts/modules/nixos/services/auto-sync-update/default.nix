{...}: {
  flake.modules.nixos.services_auto-sync-update = {
    config,
    lib,
    options,
    pkgs,
    ...
  }: let
    cfg = config.services.autoSyncUpdate;
    hasLaunchd = options ? launchd;
    hasSystemd = options ? systemd;
    defaultRebuildCommand =
      if hasLaunchd
      then ["/run/current-system/sw/bin/darwin-rebuild" "switch"]
      else ["/run/current-system/sw/bin/nixos-rebuild" "switch"];
    defaultScheduleRebootCommand =
      if hasLaunchd
      then [
        "/sbin/shutdown"
        "-r"
        "+${toString (cfg.rebootDelaySeconds / 60)}"
        "nix-auto-sync-update scheduled reboot after applying updates"
      ]
      else [
        "/run/current-system/sw/bin/systemd-run"
        "--unit=nix-auto-sync-update-reboot"
        "--description=Reboot after nix-auto-sync-update"
        "--on-active=${toString cfg.rebootDelaySeconds}s"
        "--timer-property=AccuracySec=1min"
        "--collect"
        "/run/current-system/sw/bin/systemctl"
        "reboot"
      ];
    rebuildCommand = lib.concatMapStringsSep " " lib.escapeShellArg cfg.rebuildCommand;
    rebootRequiredCommand =
      lib.optionalString (cfg.rebootRequiredCommand != null)
      (lib.concatMapStringsSep " " lib.escapeShellArg cfg.rebootRequiredCommand);
    scheduleRebootCommand = lib.concatMapStringsSep " " lib.escapeShellArg (
      if cfg.scheduleRebootCommand != null
      then cfg.scheduleRebootCommand
      else defaultScheduleRebootCommand
    );
    hasCustomScheduleRebootCommand = cfg.scheduleRebootCommand != null;
    platform =
      if hasLaunchd
      then "darwin"
      else "linux";
    script = pkgs.writeShellApplication {
      name = "nix-auto-sync-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        pkgs.nix
        pkgs.openssh
      ];
      text = ''
        set -euo pipefail

        repo_path=${lib.escapeShellArg cfg.repositoryPath}
        flake_host=${lib.escapeShellArg cfg.flakeHost}
        branch=${lib.escapeShellArg cfg.branch}
        env_file="''${AUTO_SYNC_ENV_FILE:-${lib.escapeShellArg cfg.environmentFile}}"
        lock_dir=${lib.escapeShellArg cfg.lockDirectory}
        email_to=${lib.escapeShellArg cfg.emailTo}
        reboot_delay_seconds=${toString cfg.rebootDelaySeconds}
        platform=${lib.escapeShellArg platform}
        custom_reboot_required=${lib.escapeShellArg (lib.boolToString (cfg.rebootRequiredCommand != null))}
        custom_schedule_reboot=${lib.escapeShellArg (lib.boolToString hasCustomScheduleRebootCommand)}
        log_file="$(mktemp)"
        lock_acquired=0

        # shellcheck disable=SC2329
        cleanup() {
          rm -f "$log_file"
          if [ -n "''${askpass_file:-}" ]; then
            rm -f "$askpass_file"
          fi
          if [ -n "''${mail_file:-}" ]; then
            rm -f "$mail_file"
          fi
          if [ "$lock_acquired" -eq 1 ]; then
            rmdir "$lock_dir" 2>/dev/null || true
          fi
        }
        trap cleanup EXIT

        if ! mkdir "$lock_dir" 2>/dev/null; then
          echo "Another nix-auto-sync-update run is active; exiting."
          exit 0
        fi
        lock_acquired=1

        load_env() {
          if [ -f "$env_file" ]; then
            set -a
            # shellcheck disable=SC1090
            . "$env_file"
            set +a
          fi
        }

        configure_git_auth() {
          git_args=(-c "safe.directory=$repo_path")

          if [ -n "''${AUTO_SYNC_GIT_AUTH_HEADER:-}" ]; then
            git_args+=(-c "http.extraHeader=$AUTO_SYNC_GIT_AUTH_HEADER")
          fi

          if [ -n "''${AUTO_SYNC_GIT_TOKEN:-}" ]; then
            askpass_file="$(mktemp)"
            chmod 700 "$askpass_file"
            cat > "$askpass_file" <<'EOF'
        #!/bin/sh
        case "$1" in
          *Username*) printf '%s\n' "''${AUTO_SYNC_GIT_USERNAME:-x-access-token}" ;;
          *Password*) printf '%s\n' "''${AUTO_SYNC_GIT_TOKEN}" ;;
          *) printf '\n' ;;
        esac
        EOF
            export GIT_ASKPASS="$askpass_file"
            export GIT_TERMINAL_PROMPT=0
          fi
        }

        send_mail() {
          subject="$1"
          if [ -z "''${AUTO_SYNC_SMTP_URL:-}" ]; then
            echo "AUTO_SYNC_SMTP_URL is not set; cannot send email: $subject" >&2
            return 0
          fi

          mail_from="''${AUTO_SYNC_SMTP_FROM:-nix-auto-sync-update@$(/bin/hostname -f 2>/dev/null || /bin/hostname)}"
          mail_to="''${AUTO_SYNC_SMTP_TO:-$email_to}"
          mail_file="$(mktemp)"

          {
            printf 'From: %s\r\n' "$mail_from"
            printf 'To: %s\r\n' "$mail_to"
            printf 'Subject: %s\r\n' "$subject"
            printf 'Content-Type: text/plain; charset=UTF-8\r\n'
            printf '\r\n'
            cat
          } > "$mail_file"

          curl_args=(
            --fail
            --show-error
            --silent
            --url "$AUTO_SYNC_SMTP_URL"
            --mail-from "$mail_from"
            --mail-rcpt "$mail_to"
            --upload-file "$mail_file"
          )

          if [ "''${AUTO_SYNC_SMTP_REQUIRE_TLS:-1}" != "0" ]; then
            curl_args+=(--ssl-reqd)
          fi

          if [ -n "''${AUTO_SYNC_SMTP_USERNAME:-}" ] || [ -n "''${AUTO_SYNC_SMTP_PASSWORD:-}" ]; then
            curl_args+=(--user "''${AUTO_SYNC_SMTP_USERNAME:-}:''${AUTO_SYNC_SMTP_PASSWORD:-}")
          fi

          if ! curl "''${curl_args[@]}"; then
            echo "Failed to send email: $subject" >&2
          fi
        }

        send_failure_mail() {
          status="$1"

          {
            printf 'nix-auto-sync-update failed on %s with exit status %s.\n\n' "$flake_host" "$status"
            printf 'Repository: %s\n' "$repo_path"
            printf 'Branch: %s\n\n' "$branch"
            printf 'Captured output:\n'
            cat "$log_file"
          } | send_mail "[watchdog] nix auto-sync-update failed on $flake_host"
        }

        reboot_required() {
          if [ "''${AUTO_SYNC_FORCE_REBOOT_REQUIRED:-0}" = "1" ]; then
            return 0
          fi

          if [ "$custom_reboot_required" = "true" ]; then
            reboot_required_cmd=(${rebootRequiredCommand})
            "''${reboot_required_cmd[@]}"
            return "$?"
          fi

          if [ "$platform" = "linux" ]; then
            if [ ! -e /run/current-system ] || [ ! -e /run/booted-system ]; then
              return 1
            fi

            for artifact in kernel initrd kernel-modules; do
              if [ ! -e "/run/current-system/$artifact" ]; then
                continue
              fi

              current_artifact="$(readlink -f "/run/current-system/$artifact")"
              booted_artifact="$(readlink -f "/run/booted-system/$artifact" 2>/dev/null || true)"
              if [ "$current_artifact" != "$booted_artifact" ]; then
                echo "Reboot required: $artifact changed from $booted_artifact to $current_artifact."
                return 0
              fi
            done

            return 1
          fi

          if [ "$platform" = "darwin" ]; then
            if [ -e /var/run/reboot-required ] || [ -e /tmp/restart-required ]; then
              echo "Reboot required: reboot marker file exists."
              return 0
            fi

            return 1
          fi

          return 1
        }

        schedule_reboot() {
          if [ "$platform" = "linux" ] && [ "$custom_schedule_reboot" != "true" ]; then
            /run/current-system/sw/bin/systemctl stop nix-auto-sync-update-reboot.timer nix-auto-sync-update-reboot.service 2>/dev/null || true
            /run/current-system/sw/bin/systemctl reset-failed nix-auto-sync-update-reboot.timer nix-auto-sync-update-reboot.service 2>/dev/null || true
          fi

          if [ "$platform" = "darwin" ] && [ "$custom_schedule_reboot" != "true" ]; then
            if [ -f /var/run/shutdown.pid ] && kill -0 "$(< /var/run/shutdown.pid)" 2>/dev/null; then
              echo "A shutdown is already scheduled; leaving it in place."
              return 0
            fi
          fi

          schedule_reboot_cmd=(${scheduleRebootCommand})
          "''${schedule_reboot_cmd[@]}"
        }

        handle_required_reboot() {
          if ! reboot_required; then
            return 0
          fi

          schedule_output="$(schedule_reboot 2>&1)"
          printf '%s\n' "$schedule_output"

          {
            printf 'nix-auto-sync-update applied updates on %s and detected that a reboot is required.\n\n' "$flake_host"
            printf 'Repository: %s\n' "$repo_path"
            printf 'Branch: %s\n' "$branch"
            printf 'Reboot delay: %s seconds\n\n' "$reboot_delay_seconds"
            printf 'The reboot has been scheduled for 12 hours after the update.\n\n'
            printf 'Scheduler output:\n%s\n' "$schedule_output"
          } | send_mail "[watchdog] reboot required on $flake_host"
        }

        run_update() {
          load_env
          configure_git_auth
          updated=0

          if [ ! -d "$repo_path/.git" ]; then
            if [ -z "''${AUTO_SYNC_GIT_REPOSITORY_URL:-}" ]; then
              echo "$repo_path is not a git checkout and AUTO_SYNC_GIT_REPOSITORY_URL is not set." >&2
              return 1
            fi

            mkdir -p "$(dirname "$repo_path")"
            git "''${git_args[@]}" clone --branch "$branch" "$AUTO_SYNC_GIT_REPOSITORY_URL" "$repo_path"
            updated=1
          fi

          cd "$repo_path"
          before_rev="$(git rev-parse HEAD 2>/dev/null || true)"
          git "''${git_args[@]}" fetch --prune origin "$branch"
          if git show-ref --verify --quiet "refs/heads/$branch"; then
            git "''${git_args[@]}" checkout "$branch"
          else
            git "''${git_args[@]}" checkout --track -b "$branch" "origin/$branch"
          fi
          git "''${git_args[@]}" merge --ff-only "origin/$branch"
          after_rev="$(git rev-parse HEAD)"
          if [ "$before_rev" != "$after_rev" ]; then
            updated=1
          fi

          rebuild_cmd=(${rebuildCommand})
          "''${rebuild_cmd[@]}" --flake "path:$repo_path#$flake_host"

          if [ "$updated" -eq 1 ]; then
            handle_required_reboot
          fi
        }

        if run_update > >(tee -a "$log_file") 2>&1; then
          exit 0
        else
          status=$?
          send_failure_mail "$status"
          exit "$status"
        fi
      '';
    };
  in {
    options.services.autoSyncUpdate = {
      enable = lib.mkEnableOption "automatic repository sync and host rebuild";

      flakeHost = lib.mkOption {
        type = lib.types.str;
        description = "Flake output host name to switch after the repository is pulled.";
      };

      repositoryPath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nix-darwin";
        description = "Local checkout path for this repository.";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Git branch to fast-forward and apply.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nix-auto-sync-update.env";
        description = "Optional shell-style environment file containing Git and SMTP credentials.";
      };

      emailTo = lib.mkOption {
        type = lib.types.str;
        default = "lisa@scheers.tech";
        description = "Default watchdog email recipient.";
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3000;
        description = "Number of seconds between sync attempts.";
      };

      rebootDelaySeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 43200;
        description = "Number of seconds to wait before rebooting after an update that requires a reboot.";
      };

      lockDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/var/run/nix-auto-sync-update.lock";
        description = "Runtime lock directory used to prevent overlapping runs.";
      };

      rebuildCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = defaultRebuildCommand;
        description = "Command used to switch the host after pulling the repository.";
      };

      rebootRequiredCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional command that exits 0 when a reboot should be scheduled.";
      };

      scheduleRebootCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional command used to schedule the delayed reboot.";
      };
    };

    config = lib.mkIf cfg.enable (
      lib.optionalAttrs hasSystemd {
        systemd.services.nix-auto-sync-update = {
          description = "Pull this Nix repository and apply host changes";
          restartIfChanged = false;
          stopIfChanged = false;
          wants = ["network-online.target"];
          after = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe script;
          };
        };

        systemd.timers.nix-auto-sync-update = {
          description = "Run nix-auto-sync-update every five minutes";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnActiveSec = "${toString cfg.intervalSeconds}s";
            OnUnitActiveSec = "${toString cfg.intervalSeconds}s";
            AccuracySec = "30s";
            Unit = "nix-auto-sync-update.service";
          };
        };
      }
      // lib.optionalAttrs hasLaunchd {
        launchd.daemons.nix-auto-sync-update.serviceConfig = {
          Label = "tech.scheers.nix-auto-sync-update";
          ProgramArguments = [(lib.getExe script)];
          RunAtLoad = false;
          StartInterval = cfg.intervalSeconds;
          StandardOutPath = "/var/log/nix-auto-sync-update.log";
          StandardErrorPath = "/var/log/nix-auto-sync-update.log";
        };
      }
    );
  };
}
