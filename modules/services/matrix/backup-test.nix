{lib, ...}: {
  perSystem = {pkgs, ...}: {
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      matrix-backup = pkgs.runCommand "matrix-backup-boundaries" {
        nativeBuildInputs = [pkgs.bash (pkgs.python3.withPackages (ps: [ps.pyyaml]))];
      } ''
        python -B -c 'import yaml, hashlib, unittest'
        export RESTORE_CHECK_SCRIPT=${./restore-check.py}
        python -B ${./test_restore_check.py}

        mkdir bin
        cat > bin/systemctl <<'SH'
        #!/bin/sh
        echo "$*" >> "$RESUME_LOG"
        SH
        chmod +x bin/systemctl
        export PATH="$PWD/bin:$PATH"
        export RESUME_LOG="$PWD/resume.log"
        export MATRIX_BACKUP_STATE_FILE="$PWD/state"
        echo '1 0' > "$MATRIX_BACKUP_STATE_FILE"
        bash -euo pipefail ${./backup-resume.sh}
        test "$(cat "$RESUME_LOG")" = 'start matrix-synapse.service'
        test ! -e "$MATRIX_BACKUP_STATE_FILE"
        bash -euo pipefail ${./backup-resume.sh}
        test "$(wc -l < "$RESUME_LOG")" -eq 1
        echo '1 1 1' > "$MATRIX_BACKUP_STATE_FILE"
        bash -euo pipefail ${./backup-resume.sh}
        tail -n 3 "$RESUME_LOG" > order
        printf 'start matrix-synapse.service\nstart pluralmatrix.service\nstart mautrix-discord.service\n' > expected
        cmp order expected
        echo 'invalid 1' > "$MATRIX_BACKUP_STATE_FILE"
        if bash -euo pipefail ${./backup-resume.sh}; then
          echo 'invalid recovery state accepted' >&2
          exit 1
        fi
        test -f "$MATRIX_BACKUP_STATE_FILE"
        touch "$out"
      '';
    };
  };
}
