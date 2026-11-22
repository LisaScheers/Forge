{config, ...}: let
  nook = config.network.nook;
  endpoint = "https://cliproxy.local.bylisa.dev";
  keyFile = ../../security/agenix/secrets/shared/ai-proxy-client-key.age;
  # Tailscale chooses a direct LAN path at home and keeps the same address remotely.
  addresses.${nook.tailscale} = ["cliproxy.local.bylisa.dev"];
  clientSecret = {
    file = keyFile;
    owner = "lisa";
    mode = "0400";
  };
in {
  nixos.base.networking.hosts = addresses;
  darwin.base.forge.hosts = addresses;
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
      };
    };
    home.sessionVariables = {
      OPENAI_BASE_URL = "${endpoint}/v1";
      ANTHROPIC_BASE_URL = endpoint;
    };
  };
}
