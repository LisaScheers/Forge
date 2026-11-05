let
  endpoint = "https://cliproxy.local.bylisa.dev";
  keyFile = ../../security/agenix/secrets/shared/ai-proxy-client-key.age;
  # Tailscale chooses a direct LAN path at home and keeps the same address remotely.
  addresses."100.106.233.104" = ["cliproxy.local.bylisa.dev"];
  clientSecret = {
    file = keyFile;
    owner = "lisa";
    mode = "0400";
  };
in {
  nixos.base.networking.hosts = addresses;
  darwin.base.system.activationScripts.postActivation.text = ''
    proxy_hosts_file=$(mktemp /tmp/ai-proxy-hosts.XXXXXX)
    /usr/bin/awk '
      $0 == "# nix-darwin: cliproxy begin" { skip = 1; next }
      $0 == "# nix-darwin: cliproxy end" { skip = 0; next }
      !skip { print }
    ' /etc/hosts > "$proxy_hosts_file"
    cat >> "$proxy_hosts_file" <<'EOF'
    # nix-darwin: cliproxy begin
    100.106.233.104 cliproxy.local.bylisa.dev
    # nix-darwin: cliproxy end
    EOF
    install -m 0644 "$proxy_hosts_file" /etc/hosts
    rm -f "$proxy_hosts_file"
  '';
  darwin.vega.age.secrets.ai-proxy-client-key = clientSecret;
  nixos.atlas.age.secrets.ai-proxy-client-key = clientSecret;

  home.lisa = {
    config,
    lib,
    pkgs,
    osConfig ? null,
    ...
  }: let
    secretPath =
      if osConfig != null && osConfig.age.secrets ? ai-proxy-client-key
      then osConfig.age.secrets.ai-proxy-client-key.path
      else "${config.xdg.configHome}/cli-proxy-api-plus/client-api-key";
  in {
    programs.codex.settings = {
      model_provider = "nook";
      model_providers.nook = {
        name = "CLIProxy on Nook";
        base_url = "${endpoint}/v1";
        wire_api = "responses";
        supports_websockets = true;
        auth = {
          command = "${pkgs.coreutils}/bin/cat";
          args = [secretPath];
        };
      };
    };
    programs.antigravity-cli = lib.mkIf config.programs.antigravity-cli.enable {
      package = pkgs.symlinkJoin {
        name = "antigravity-through-nook";
        paths = [pkgs.antigravity-cli];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram "$out/bin/agy" \
            --set GOOGLE_GEMINI_BASE_URL ${lib.escapeShellArg endpoint} \
            --run ${lib.escapeShellArg ''GEMINI_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg secretPath})" || exit 1; export GEMINI_API_KEY''}
        '';
      };
      settings = {
        modelProvider = "gemini";
        model = lib.mkForce "Gemini 3.8 Flash (High)";
      };
    };
    home.sessionVariables = {
      OPENAI_BASE_URL = "${endpoint}/v1";
      ANTHROPIC_BASE_URL = endpoint;
    };
    # T3's active Codex driver reads the same Codex provider configuration.
    programs.t3code.userSettings.providerInstances.codex.config.launchArgs =
      lib.mkForce "-c model_provider=\"nook\"";
  };
}
