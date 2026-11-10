{
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}: let
  version = "8.0.56-0";

  targets = {
    aarch64-darwin = {
      asset = "CLIProxyAPIPlus_${version}_darwin_aarch64_no-plugin.tar.gz";
      hash = "sha256:5f418185e2f3e446433da03174bc114ad6694a1cc0d75309975badf911d78b84";
    };
    x86_64-darwin = {
      asset = "CLIProxyAPIPlus_${version}_darwin_amd64_no-plugin.tar.gz";
      hash = "sha256:03f6293cf2b37868ff43d9685e33d12f693181a2310b47d19ca8f5cbe18b978c";
    };
    aarch64-linux = {
      asset = "CLIProxyAPIPlus_${version}_linux_aarch64_no-plugin.tar.gz";
      hash = "sha256:1418c8a6891fd1c0a070850e1a1b71d95b0711036c69dee99b10f69a04211b68";
    };
    x86_64-linux = {
      asset = "CLIProxyAPIPlus_${version}_linux_amd64_no-plugin.tar.gz";
      hash = "sha256:cc9fb004be10015a9de292b4fccde422a270ea7c27b200b129448717883261ff";
    };
  };

  target = targets.${stdenv.hostPlatform.system};
in
  stdenvNoCC.mkDerivation {
    pname = "cli-proxy-api-plus";
    inherit version;

    src = fetchurl {
      url = "https://github.com/kaitranntt/CLIProxyAPIPlus/releases/download/v${version}/${target.asset}";
      inherit (target) hash;
    };

    sourceRoot = ".";
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 cli-proxy-api-plus "$out/bin/cli-proxy-api-plus"
      install -Dm444 config.example.yaml "$out/share/doc/cli-proxy-api-plus/config.example.yaml"
      install -Dm444 README.md "$out/share/doc/cli-proxy-api-plus/README.md"
      install -Dm444 LICENSE "$out/share/licenses/cli-proxy-api-plus/LICENSE"

      runHook postInstall
    '';

    meta = {
      description = "OpenAI, Gemini, Claude, Codex, and Grok compatible API proxy";
      homepage = "https://github.com/kaitranntt/CLIProxyAPIPlus";
      license = lib.licenses.mit;
      mainProgram = "cli-proxy-api-plus";
      platforms = builtins.attrNames targets;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
