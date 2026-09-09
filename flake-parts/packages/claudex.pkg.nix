{
  bash,
  claude-code,
  coreutils,
  curl,
  fetchFromGitHub,
  fetchurl,
  findutils,
  gawk,
  gnugrep,
  gnused,
  lib,
  lsof,
  makeWrapper,
  netcat,
  openssl,
  stdenv,
  stdenvNoCC,
}: let
  version = "0.1.1";
  cliProxyApiVersion = "7.2.74";

  cliProxyApiTargets = {
    aarch64-darwin = {
      asset = "CLIProxyAPI_${cliProxyApiVersion}_darwin_aarch64.tar.gz";
      hash = "sha256-ozIpYvCIWjK1A+2m/sWeljpQVDqk5R0hZ0hLnzjUeIY=";
    };
    x86_64-darwin = {
      asset = "CLIProxyAPI_${cliProxyApiVersion}_darwin_amd64.tar.gz";
      hash = "sha256-Ep4uxhOAIeUFFX0f7TETMybryAAQYvKtzUCl3Wh78Co=";
    };
    aarch64-linux = {
      asset = "CLIProxyAPI_${cliProxyApiVersion}_linux_aarch64.tar.gz";
      hash = "sha256-w+NHxis7kfxQwdp1af9arCwUyk+wppxinnqs6Dd0j/c=";
    };
    x86_64-linux = {
      asset = "CLIProxyAPI_${cliProxyApiVersion}_linux_amd64.tar.gz";
      hash = "sha256-aVKjt9qoWL+6QACJcNbsRuefhUKQQ77u8VyvdP5FoBA=";
    };
  };

  target = cliProxyApiTargets.${stdenv.hostPlatform.system};

  cliProxyApi = stdenvNoCC.mkDerivation {
    pname = "cli-proxy-api";
    version = cliProxyApiVersion;

    src = fetchurl {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${cliProxyApiVersion}/${target.asset}";
      inherit (target) hash;
    };

    sourceRoot = ".";
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 cli-proxy-api "$out/bin/cli-proxy-api"
      sha256sum "$out/bin/cli-proxy-api" | cut -d ' ' -f 1 > "$out/bin/.binary-sha256"

      runHook postInstall
    '';
  };
in
  stdenvNoCC.mkDerivation {
    pname = "claudex";
    inherit version;

    src = fetchFromGitHub {
      owner = "liuzhao1225";
      repo = "claudex";
      rev = "6246fc35919e122c774cddc270712ca9ac98ccad";
      hash = "sha256-E/lvqtw17qWY/0GNMSdJtmWOFsCOF8prBmrRtBNTE8c=";
    };

    nativeBuildInputs = [makeWrapper];

    postPatch = ''
      substituteInPlace bin/claudex \
        --replace-fail 'LOCK_FILE="$DATA_DIR/deps/cliproxyapi.lock"' 'LOCK_FILE="'$out'/share/claudex/cliproxyapi.lock"' \
        --replace-fail 'CPA_BIN="$CPA_ROOT/current/cli-proxy-api"' 'CPA_BIN="${cliProxyApi}/bin/cli-proxy-api"' \
        --replace-fail 'download_cpa() {' 'download_cpa() {
        [ -x "$CPA_BIN" ] && return 0' \
        --replace-fail 'run_locked update_command' 'die "Claudex is managed by Nix; update your flake instead"' \
        --replace-fail 'run_locked rollback_command' 'die "Claudex is managed by Nix; roll back your system generation instead"' \
        --replace-fail 'run_locked uninstall_command "$@"' 'die "Claudex is managed by Nix; remove it from your Home Manager packages instead"' \
        --replace-fail 'claudex update|rollback' 'claudex update|rollback                    Disabled (managed by Nix)' \
        --replace-fail 'claudex uninstall [--keep-auth]' 'claudex uninstall [--keep-auth]           Disabled (managed by Nix)'
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 bin/claudex "$out/bin/claudex"
      install -Dm444 deps/cliproxyapi.lock "$out/share/claudex/cliproxyapi.lock"
      patchShebangs "$out/bin/claudex"

      wrapProgram "$out/bin/claudex" \
        --prefix PATH : ${
        lib.makeBinPath [
          bash
          claude-code
          coreutils
          curl
          findutils
          gawk
          gnugrep
          gnused
          lsof
          netcat
          openssl
        ]
      }

      runHook postInstall
    '';

    meta = {
      description = "Run Codex subscription models inside Claude Code through a private local proxy";
      homepage = "https://github.com/liuzhao1225/claudex";
      license = lib.licenses.mit;
      mainProgram = "claudex";
      platforms = builtins.attrNames cliProxyApiTargets;
    };
  }
