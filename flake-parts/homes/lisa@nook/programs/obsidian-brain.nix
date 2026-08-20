{
  config,
  lib,
  pkgs,
  ...
}: let
  vaultPath = "/home/lisa/obsidian/brain";
  skillNames = [
    "obsidian-capture-fleeting"
    "obsidian-capture-literature"
    "obsidian-write-atomic"
    "obsidian-refactor-selection"
    "obsidian-process-fleeting"
    "obsidian-process-literature"
    "obsidian-manage-project"
    "obsidian-compose-project"
    "obsidian-daily-review"
  ];
  vaultSkillLinks = builtins.listToAttrs (map (skillName: {
      name = ".agents/skills/${skillName}";
      value.source =
        config.lib.file.mkOutOfStoreSymlink
        "${vaultPath}/.agents/skills/${skillName}";
    })
    skillNames);
  reviewRunner = pkgs.writeShellApplication {
    name = "obsidian-brain-daily-review";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      umask 077

      readonly vault_dir="${vaultPath}"
      readonly state_dir="''${XDG_STATE_HOME:-/home/lisa/.local/state}/obsidian-brain"
      readonly lock_file="$state_dir/daily-review.lock"
      readonly date_marker="$state_dir/last-successful-date"
      readonly latest_brief="$state_dir/daily-review-latest.md"

      mkdir -p "$state_dir"
      chmod 0700 "$state_dir"

      exec 9>"$lock_file"
      if ! flock -n 9; then
        echo "An Obsidian daily review is already running."
        exit 0
      fi

      review_date="$(TZ=Europe/Brussels date +%F)"
      readonly review_date
      completed_date=""
      if [[ -f "$date_marker" ]]; then
        IFS= read -r completed_date <"$date_marker" || completed_date=""
      fi

      if [[ "$completed_date" == "$review_date" ]]; then
        echo "The Obsidian daily review for $review_date is already complete."
        exit 0
      fi

      if [[ ! -d "$vault_dir/.agents/skills/obsidian-daily-review" ]]; then
        echo "The Obsidian daily-review skill is missing from $vault_dir." >&2
        exit 1
      fi

      if [[ ! -r /home/lisa/.agents/skills/unslop/SKILL.md ]]; then
        echo "The user-scope unslop skill is missing." >&2
        exit 1
      fi

      run_dir="$(mktemp -d "$state_dir/.daily-review.XXXXXXXX")"
      readonly run_dir
      trap 'rm -rf -- "$run_dir"' EXIT

      readonly candidate_brief="$run_dir/daily-review.md"
      readonly staged_brief="$state_dir/.daily-review-latest.md.new"
      readonly staged_marker="$state_dir/.last-successful-date.new"
      readonly review_prompt="Use \$obsidian-daily-review to prepare the current read-only review brief. Apply \$unslop only to your own prose. Read only the vault in the current working directory. Do not modify any file, use web access, invoke MCP servers or connectors, call an external service other than the Codex request itself, or take an external action. Return only the Markdown brief."

      unset OPENAI_API_KEY
      unset CODEX_API_KEY

      if ! ${pkgs.codex}/bin/codex \
        --ask-for-approval never \
        --disable plugins \
        --disable apps \
        --disable remote_plugin \
        --disable plugin_sharing \
        --disable enable_mcp_apps \
        --disable tool_call_mcp_elicitation \
        --disable browser_use \
        --disable browser_use_external \
        --disable browser_use_full_cdp_access \
        --disable in_app_browser \
        --disable computer_use \
        --disable image_generation \
        --disable hooks \
        --disable multi_agent \
        --disable skill_mcp_dependency_install \
        exec \
        --ephemeral \
        --ignore-user-config \
        --sandbox read-only \
        --skip-git-repo-check \
        --cd "$vault_dir" \
        --json \
        --output-last-message "$candidate_brief" \
        "$review_prompt"
      then
        echo "Codex failed to prepare the Obsidian daily review." >&2
        exit 1
      fi

      if [[ ! -s "$candidate_brief" ]]; then
        echo "Codex returned an empty Obsidian daily review." >&2
        exit 1
      fi

      install -m 0600 "$candidate_brief" "$staged_brief"
      mv -f "$staged_brief" "$latest_brief"

      printf '%s\n' "$review_date" >"$staged_marker"
      chmod 0600 "$staged_marker"
      mv -f "$staged_marker" "$date_marker"
    '';
  };
in {
  home.file =
    vaultSkillLinks
    // {
      ".agents/skills/unslop".source =
        config.lib.file.mkOutOfStoreSymlink
        "/home/lisa/.codex/skills/unslop";
    };

  home.packages = [reviewRunner];

  systemd.user.services.obsidian-brain-daily-review = {
    Unit = {
      Description = "Prepare the read-only Obsidian daily review";
      ConditionPathIsDirectory = vaultPath;
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe reviewRunner;
      UMask = "0077";
    };
  };

  systemd.user.timers.obsidian-brain-daily-review = {
    Unit.Description = "Prepare the Obsidian daily review at 09:00 Europe/Brussels";
    Timer = {
      OnCalendar = "*-*-* 09:00:00 Europe/Brussels";
      Persistent = true;
      Unit = "obsidian-brain-daily-review.service";
    };
    Install.WantedBy = ["timers.target"];
  };
}
