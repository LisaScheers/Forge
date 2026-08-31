{localFlake}: {
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  cfg = config.services.cli-proxy-api-plus;
  yamlFormat = pkgs.formats.yaml {};

  baseUrl = "http://${cfg.host}:${toString cfg.port}";
  openAIBaseUrl = "${baseUrl}/v1";
  configFile = "${cfg.configDir}/config.yaml";

  hasProgram = name: lib.hasAttrByPath ["programs" name "enable"] options;
  wantsIntegration = name:
    cfg.integrations.enable
    && builtins.elem name cfg.integrations.programs;

  clientModels =
    map (id: {
      inherit id;
      name = id;
    })
    cfg.integrations.models;

  openRouterConfig = {
    name = "openrouter";
    prefix = "openrouter";
    base-url = "https://openrouter.ai/api/v1";
    disabled = false;
    api-key-entries = lib.optional (cfg.openrouter.apiKeyFile != null) [
      {api-key = "@OPENROUTER_API_KEY@";}
    ];
    models = cfg.openrouter.models;
  };

  generatedSettings = {
    inherit (cfg) host port;
    auth-dir = cfg.authDir;
    api-keys = [cfg.clientApiKey];
    remote-management = {
      allow-remote = false;
      secret-key = "";
      disable-control-panel = true;
    };
    openai-compatibility = lib.optional cfg.openrouter.enable openRouterConfig;
  };

  renderedConfig = yamlFormat.generate "cli-proxy-api-plus.yaml" (
    lib.recursiveUpdate cfg.settings generatedSettings
  );

  runner = pkgs.writeShellApplication {
    name = "cli-proxy-api-plus-managed";
    runtimeInputs = [pkgs.coreutils pkgs.yq-go];
    text = ''
      umask 077
      mkdir -p ${lib.escapeShellArg cfg.configDir} ${lib.escapeShellArg cfg.authDir}
      install -m600 ${lib.escapeShellArg renderedConfig} ${lib.escapeShellArg configFile}

      ${lib.optionalString (cfg.openrouter.enable && cfg.openrouter.apiKeyFile != null) ''
        if [[ -s ${lib.escapeShellArg cfg.openrouter.apiKeyFile} ]]; then
          openrouter_api_key="$(tr -d '\r\n' < ${lib.escapeShellArg cfg.openrouter.apiKeyFile})"
          OPENROUTER_API_KEY="$openrouter_api_key" yq --inplace '
            (."openai-compatibility"[] | select(.name == "openrouter") | ."api-key-entries") =
              [{"api-key": strenv(OPENROUTER_API_KEY)}] |
            (."openai-compatibility"[] | select(.name == "openrouter") | .disabled) = false
          ' ${lib.escapeShellArg configFile}
          unset openrouter_api_key
        else
          yq --inplace '
            (."openai-compatibility"[] | select(.name == "openrouter") | ."api-key-entries") = [] |
            (."openai-compatibility"[] | select(.name == "openrouter") | .disabled) = true
          ' ${lib.escapeShellArg configFile}
          echo "CLIProxyAPIPlus: OpenRouter API key file is missing or empty: ${cfg.openrouter.apiKeyFile}" >&2
        fi
      ''}

      exec ${lib.getExe cfg.package} -config ${lib.escapeShellArg configFile} "$@"
    '';
  };

  managedPackage = pkgs.writeShellApplication {
    name = "cli-proxy-api-plus";
    text = ''
      exec ${lib.getExe runner} "$@"
    '';
  };
in {
  options.services.cli-proxy-api-plus = {
    enable = lib.mkEnableOption "CLIProxyAPIPlus local API proxy";

    package = lib.mkPackageOption pkgs "cli-proxy-api-plus" {};

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which CLIProxyAPIPlus listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8317;
      description = "Port on which CLIProxyAPIPlus listens.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/cli-proxy-api-plus";
      defaultText = lib.literalExpression ''"''${config.xdg.configHome}/cli-proxy-api-plus"'';
      description = "Directory containing the generated runtime configuration.";
    };

    authDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/cli-proxy-api-plus/auth";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/cli-proxy-api-plus/auth"'';
      description = "Mutable directory containing OAuth credentials.";
    };

    clientApiKey = lib.mkOption {
      type = lib.types.str;
      default = "sk-local-cli-proxy";
      description = ''
        API key used by local agent clients. The default is suitable only while
        the service listens on loopback.
      '';
    };

    settings = lib.mkOption {
      inherit (yamlFormat) type;
      default = {};
      description = ''
        Extra CLIProxyAPIPlus settings. Dedicated module options take
        precedence over values set here.
      '';
    };

    openrouter = {
      enable = lib.mkEnableOption "OpenRouter as an OpenAI-compatible provider";

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/agenix/openrouter-api-key";
        description = ''
          File containing the OpenRouter API key. The module reads it when the
          proxy starts, so the key never enters the Nix store.
        '';
      };

      models = lib.mkOption {
        type = lib.types.listOf yamlFormat.type;
        default = [
          {
            name = "openrouter/auto";
            alias = "auto";
            display-name = "OpenRouter Auto";
          }
        ];
        description = "OpenRouter model mappings exposed by CLIProxyAPIPlus.";
      };
    };

    integrations = {
      enable = lib.mkEnableOption "configuration of enabled Home Manager agent programs" // {default = true;};

      programs = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [
          "aichat"
          "aider-chat"
          "antigravity-cli"
          "claude-code"
          "codex"
          "crush"
          "mistral-vibe"
          "opencode"
          "pi-coding-agent"
        ]);
        default = [
          "aichat"
          "aider-chat"
          "antigravity-cli"
          "claude-code"
          "codex"
          "crush"
          "mistral-vibe"
          "opencode"
          "pi-coding-agent"
        ];
        description = ''
          Official Home Manager agent program modules to point at the local
          proxy when they are enabled.
        '';
      };

      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "gpt-5.6-sol";
        description = "Default proxy model selected in integrated agents.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "gpt-5.6-sol"
          "openrouter/auto"
        ];
        description = "Proxy model IDs exposed to clients that require a static model catalog.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = builtins.elem cfg.integrations.defaultModel cfg.integrations.models;
          message = "services.cli-proxy-api-plus.integrations.defaultModel must be present in integrations.models";
        }
      ];

      home.packages = [managedPackage];

      systemd.user.services.cli-proxy-api-plus = {
        Unit = {
          Description = "CLIProxyAPIPlus local API proxy";
          After = ["network.target"];
        };
        Service = {
          ExecStart = lib.getExe runner;
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = ["default.target"];
      };

      launchd.agents.cli-proxy-api-plus = {
        enable = true;
        config = {
          ProgramArguments = [
            (lib.getExe runner)
          ];
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };
    }

    (lib.mkIf (wantsIntegration "aichat" && config.programs.aichat.enable) {
      programs.aichat.settings = {
        model = lib.mkDefault "cli-proxy-api-plus:${cfg.integrations.defaultModel}";
        clients = lib.mkBefore [
          {
            type = "openai-compatible";
            name = "cli-proxy-api-plus";
            api_base = openAIBaseUrl;
            api_key = cfg.clientApiKey;
            models =
              map (model: {
                name = model.id;
                supports_function_calling = true;
              })
              clientModels;
          }
        ];
      };
    })

    (lib.mkIf (wantsIntegration "aider-chat" && config.programs.aider-chat.enable) {
      programs.aider-chat.settings = {
        model = lib.mkDefault "openai/${cfg.integrations.defaultModel}";
        openai-api-base = lib.mkDefault openAIBaseUrl;
        openai-api-key = lib.mkDefault cfg.clientApiKey;
      };
    })

    (lib.mkIf (wantsIntegration "antigravity-cli" && config.programs.antigravity-cli.enable) {
      home.sessionVariables = {
        GEMINI_API_KEY = lib.mkDefault cfg.clientApiKey;
        GEMINI_MODEL = lib.mkDefault cfg.integrations.defaultModel;
        GOOGLE_GEMINI_BASE_URL = lib.mkDefault baseUrl;
      };
    })

    (lib.mkIf (wantsIntegration "claude-code" && config.programs.claude-code.enable) {
      programs.claude-code.settings = {
        model = lib.mkDefault cfg.integrations.defaultModel;
        env = {
          ANTHROPIC_AUTH_TOKEN = lib.mkDefault cfg.clientApiKey;
          ANTHROPIC_BASE_URL = lib.mkDefault baseUrl;
          CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = lib.mkDefault "1";
        };
      };
    })

    (lib.mkIf (wantsIntegration "codex" && config.programs.codex.enable) {
      programs.codex.settings = {
        model = lib.mkDefault cfg.integrations.defaultModel;
        model_provider = lib.mkDefault "cli-proxy-api-plus";
        model_providers.cli-proxy-api-plus = {
          name = "CLIProxyAPI Plus";
          base_url = openAIBaseUrl;
          experimental_bearer_token = cfg.clientApiKey;
          wire_api = "responses";
          requires_openai_auth = true;
          supports_websockets = true;
        };
      };
    })

    (lib.optionalAttrs (hasProgram "crush") {
      programs.crush.settings = lib.mkIf (wantsIntegration "crush" && config.programs.crush.enable) {
        models = {
          large = lib.mkDefault {
            model = cfg.integrations.defaultModel;
            provider = "cli-proxy-api-plus";
          };
          small = lib.mkDefault {
            model = cfg.integrations.defaultModel;
            provider = "cli-proxy-api-plus";
          };
        };
        providers.cli-proxy-api-plus = {
          type = "openai";
          base_url = openAIBaseUrl;
          api_key = cfg.clientApiKey;
          models = clientModels;
        };
      };
    })

    (lib.mkIf (wantsIntegration "mistral-vibe" && config.programs.mistral-vibe.enable) {
      home.sessionVariables.CLIPROXYAPI_PLUS_API_KEY = lib.mkDefault cfg.clientApiKey;
      programs.mistral-vibe.settings = {
        active_model = lib.mkDefault cfg.integrations.defaultModel;
        providers = lib.mkBefore [
          {
            name = "cli-proxy-api-plus";
            backend = "generic";
            api_base = openAIBaseUrl;
            api_key_env_var = "CLIPROXYAPI_PLUS_API_KEY";
            api_style = "openai";
          }
        ];
        models = lib.mkBefore (map (model: {
            name = model.id;
            provider = "cli-proxy-api-plus";
            alias = model.id;
          })
          clientModels);
      };
    })

    (lib.mkIf (wantsIntegration "opencode" && config.programs.opencode.enable) {
      programs.opencode.settings = {
        model = lib.mkDefault "cli-proxy-api-plus/${cfg.integrations.defaultModel}";
        provider.cli-proxy-api-plus = {
          npm = "@ai-sdk/openai";
          name = "CLIProxyAPI Plus";
          options = {
            baseURL = openAIBaseUrl;
            apiKey = cfg.clientApiKey;
          };
          models = builtins.listToAttrs (map (model: {
              name = model.id;
              value.name = model.name;
            })
            clientModels);
        };
      };
    })

    (lib.mkIf (wantsIntegration "pi-coding-agent" && config.programs.pi-coding-agent.enable) {
      programs.pi-coding-agent = {
        settings = {
          defaultProvider = lib.mkDefault "cli-proxy-api-plus";
          defaultModel = lib.mkDefault cfg.integrations.defaultModel;
        };
        models.providers.cli-proxy-api-plus = {
          baseUrl = openAIBaseUrl;
          api = "openai-responses";
          apiKey = cfg.clientApiKey;
          models =
            map (model: {
              inherit (model) id name;
              reasoning = true;
            })
            clientModels;
        };
      };
    })
  ]);
}
