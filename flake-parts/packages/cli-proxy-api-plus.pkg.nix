{
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
}: let
  version = "7.2.127-7";

  targets = {
    aarch64-darwin = {
      asset = "CLIProxyAPIPlus_${version}_darwin_aarch64_no-plugin.tar.gz";
      hash = "sha256-1bhAetxWQ9hw//WMaR0k2wwifdjV0CJOU4JZu6SdEi4=";
    };
    x86_64-darwin = {
      asset = "CLIProxyAPIPlus_${version}_darwin_amd64_no-plugin.tar.gz";
      hash = "sha256-5idVe0m/ClXeQWypLvUBMlKpJms8b1O1JrX1P5m27SM=";
    };
    aarch64-linux = {
      asset = "CLIProxyAPIPlus_${version}_linux_aarch64_no-plugin.tar.gz";
      hash = "sha256-hno9pE0vSM+nfqT4fqZso7goC2Zi/MbIxqcgXfx5ZHw=";
    };
    x86_64-linux = {
      asset = "CLIProxyAPIPlus_${version}_linux_amd64_no-plugin.tar.gz";
      hash = "sha256-bP5BVeAGRnXKyafnwTSu+5SLjpVR0MdiB6xnxf2jVGc=";
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
