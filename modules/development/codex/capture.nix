{inputs, ...}: {
  overlays.codex-capture = final: _prev: {
    codex-native-capture = final.callPackage ../../../packages/codex-native-capture/package.nix {
      codex = final.callPackage "${inputs.nixpkgs}/pkgs/by-name/co/codex/package.nix" {};
    };
    codex-capture = final.symlinkJoin {
      name = "codex-capture-${final.codex-native-capture.version}";
      paths = [final.codex-native-capture];
      nativeBuildInputs = [final.makeWrapper];
      postBuild = ''
        wrapProgram "$out/bin/codex" --run 'unset OPENAI_BASE_URL; export CODEX_ROLLOUT_TRACE_ROOT="''${CODEX_ROLLOUT_TRACE_ROOT:-''${CODEX_HOME:-$HOME/.codex}/traces}"; ${final.coreutils}/bin/install -d -m 0700 "$CODEX_ROLLOUT_TRACE_ROOT"'
      '';
      meta.mainProgram = "codex";
    };
    codex-capture-sync = final.writeShellApplication {
      name = "codex-capture-sync";
      runtimeInputs = [final.coreutils final.openssh final.rsync];
      text = ''
        umask 077
        host_id=''${1:?usage: codex-capture-sync HOST}
        [[ "$host_id" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || exit 2
        traces="''${CODEX_ROLLOUT_TRACE_ROOT:-''${CODEX_HOME:-$HOME/.codex}/traces}"
        [[ -d "$traces" ]] || exit 0
        incoming=".local/state/forge-codex-capture/incoming/$host_id"
        if [[ "$host_id" == nook ]]; then
          mkdir -p "$HOME/$incoming"
          rsync -rt --safe-links --delay-updates --chmod=D700,F600 "$traces/" "$HOME/$incoming/"
        else
          rsync -rt --safe-links --delay-updates --chmod=D700,F600 \
            -e 'ssh -o BatchMode=yes -o ConnectTimeout=10' \
            --rsync-path="umask 077; mkdir -p \"\$HOME/$incoming\" && exec rsync" \
            "$traces/" "nook:$incoming/"
        fi
      '';
    };
  };

  perSystem = {pkgs, ...}: let
    nativeTest = pkgs.writeShellApplication {
      name = "codex-capture-test";
      runtimeInputs = [(pkgs.python3.withPackages (ps: [ps.aiohttp]))];
      text = ''
        export CODEX_CAPTURE_BINARY="${pkgs.codex-capture}/bin/codex"
        export PYTHONPATH="${../../../services/ai-usage}:${../../../services/ai-archive}"
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        unset CODEX_CA_CERTIFICATE
        exec python3 -B ${../../../tests/test_codex_native.py}
      '';
    };
  in {
    packages = {
      inherit (pkgs) codex-native-capture codex-capture codex-capture-sync;
      codex-capture-test = nativeTest;
    };
    # macOS preference refresh needs a login session; run the same test via
    # `nix run .#codex-capture-test` there, outside the Nix build sandbox.
    checks.codex-native-capture = pkgs.lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
      pkgs.runCommand "codex-native-capture-tests" {} ''
        ${nativeTest}/bin/codex-capture-test
        touch "$out"
      ''
    );
    checks.codex-capture-sync = pkgs.runCommand "codex-capture-sync-tests" {} ''
      export HOME="$TMPDIR/client"
      mkdir -p "$HOME/.codex/traces/trace-fixture/payloads"
      printf 'fixture\n' > "$HOME/.codex/traces/trace-fixture/payloads/1.json"
      ${pkgs.codex-capture-sync}/bin/codex-capture-sync nook
      saved="$HOME/.local/state/forge-codex-capture/incoming/nook/trace-fixture/payloads/1.json"
      cmp "$HOME/.codex/traces/trace-fixture/payloads/1.json" "$saved"
      test "$(${pkgs.coreutils}/bin/stat -c %a "$saved")" = 600
      if ${pkgs.codex-capture-sync}/bin/codex-capture-sync '../invalid'; then
        exit 1
      fi
      touch "$out"
    '';
  };

  home.lisa = {
    config,
    lib,
    pkgs,
    osConfig ? null,
    ...
  }: let
    sync = "${pkgs.codex-capture-sync}/bin/codex-capture-sync";
    hostName =
      if osConfig != null
      then osConfig.networking.hostName
      else "standalone-${pkgs.stdenv.hostPlatform.system}";
    state = "${config.xdg.stateHome}/forge-codex-capture";
  in {
    programs.codex.package = pkgs.codex-capture;
    programs.codex.settings.model_provider = "openai";
    programs.t3code.userSettings.providerInstances.codex.config.binaryPath = lib.mkForce (lib.getExe pkgs.codex-capture);
    home.packages = [pkgs.codex-capture-sync];
    home.sessionVariables.CODEX_CLI_PATH = lib.getExe pkgs.codex-capture;
    home.activation.codexCaptureState = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg state}
    '';
    launchd.agents.codex-capture-sync = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [sync hostName];
        RunAtLoad = true;
        StartInterval = 60;
        ProcessType = "Background";
        StandardOutPath = "${state}/sync.log";
        StandardErrorPath = "${state}/sync.log";
      };
    };
    systemd.user.services.codex-capture-sync = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Upload native Codex captures to Nook";
      Service = {
        Type = "oneshot";
        ExecStart = "${sync} ${hostName}";
        UMask = "0077";
      };
    };
    systemd.user.timers.codex-capture-sync = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Install.WantedBy = ["timers.target"];
      Timer = {
        OnBootSec = "1m";
        OnUnitInactiveSec = "1m";
      };
    };
  };

  darwin.vega = {
    lib,
    pkgs,
    ...
  }: {
    launchd.user.envVariables.CODEX_CLI_PATH = lib.getExe pkgs.codex-capture;
  };

  nixos.nook = {
    config,
    lib,
    pkgs,
    ...
  }: let
    incoming = "${config.users.users.lisa.home}/.local/state/forge-codex-capture/incoming";
    ingest = user: {
      description = "Archive native Codex requests and raw usage in ClickHouse";
      requires = ["ai-usage-schema.service"];
      after = ["ai-usage-schema.service"];
      unitConfig.RequiresMountsFor = ["/srv/disks/projects" "${config.users.users.${user}.home}"];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        StateDirectory = "codex-capture-ingest-${user}";
        StateDirectoryMode = "0700";
        UMask = "0077";
        EnvironmentFile = "/srv/disks/projects/ai-usage-secrets/clickhouse.env";
        ExecStart = "${pkgs.python3}/bin/python3 ${../../../services/ai-usage}/codex_trace.py --incoming ${config.users.users.${user}.home}/.local/state/forge-codex-capture/incoming --state /var/lib/codex-capture-ingest-${user}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };
  in {
    systemd.tmpfiles.rules = ["d ${incoming} 0700 lisa users - -"];
    home-manager.users.codex = {
      programs.codex.package = pkgs.codex-capture;
      home.sessionVariables.CODEX_ROLLOUT_TRACE_ROOT = "/home/codex/.local/state/forge-codex-capture/incoming/nook-codex";
    };
    systemd.services.codex.environment.CODEX_ROLLOUT_TRACE_ROOT = "/home/codex/.local/state/forge-codex-capture/incoming/nook-codex";
    systemd.services.ai-codex-ingest = ingest "lisa";
    systemd.services.ai-codex-daemon-ingest = ingest "codex";
    systemd.timers = lib.genAttrs ["ai-codex-ingest" "ai-codex-daemon-ingest"] (_: {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitInactiveSec = "30s";
      };
    });
  };
}
