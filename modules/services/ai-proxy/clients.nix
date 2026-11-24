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
    # `ai-gateway-probe`: exit 0 when the gateway lists every model its clients
    # use, 1 when one is missing, 2 when it is unreachable or refuses the key.
    # `ai-gateway-probe --infer` also asks each model for one token.
    # Antigravity sends gemini-3.8-flash (server.nix aliases it); Cognee uses
    # openrouter/glm-5.3-flash (cognee/server.nix).
    home.packages = [
      (pkgs.writeShellApplication {
        name = "ai-gateway-probe";
        text = ''exec ${pkgs.python3}/bin/python3 -I ${../../../services/ai-usage/gateway_probe.py} "$@" ${endpoint} ${lib.escapeShellArg secretPath} gemini-3.8-flash openrouter/glm-5.3-flash'';
      })
    ];
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
  };
}
