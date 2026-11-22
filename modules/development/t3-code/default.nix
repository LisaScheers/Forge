{
  config,
  inputs,
  lib,
  ...
}: let
  sharedKeybindings = lib.importJSON ./keybindings.json;
  t3Home = config.home.t3-code;
in {
  home.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # nix-darwin copies this into /Applications/Nix Apps as a real bundle, which
  # Spotlight and the Dock launch; Home Manager's symlinked copy opens as a folder.
  darwin.vega = {config, ...}: {
    environment.systemPackages = [config.home-manager.users.lisa.programs.t3code.package];
  };
  home.lisa-vega = {config, ...}: {
    imports = [t3Home];
    # The native module manages userdata; its legacy dev profile has no option.
    forge.mutablePreferences = {
      ".t3/dev/settings.json".settings = {
        providerInstances = {
          claudeAgent = {
            driver = "claudeAgent";
            enabled = false;
          };
          codex = {
            driver = "codex";
            enabled = true;
          };
          grok = {
            driver = "grok";
            enabled = false;
          };
          opencode = {
            driver = "opencode";
            enabled = false;
          };
        };
        textGenerationModelSelection = {
          instanceId = "codex";
          model = "gpt-5.5";
          options = [
            {
              id = "reasoningEffort";
              value = "high";
            }
            {
              id = "serviceTier";
              value = "default";
            }
          ];
        };
      };
      ".t3/dev/keybindings.json".settings = sharedKeybindings;
    };
    programs.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
      userSettings = {
        defaultAutoPull = true;
        defaultModelSelection = {
          instanceId = "codex";
          model = "gpt-6-astra";
          options = [
            {
              id = "reasoningEffort";
              value = "medium";
            }
            {
              id = "serviceTier";
              value = "default";
            }
          ];
        };
        providerInstances = {
          antigravity = {
            config = {
              # Empty uses T3's managed ACP runtime; the agy CLI has no ACP harness.
              binaryPath = "";
              customModels = [];
            };
            driver = "antigravity";
            enabled = true;
          };
          claudeAgent = {
            config = {
              # T3's Claude probe spawns without the login-shell PATH, so a bare
              # "claude" fails with ENOENT. The profile path survives generations.
              binaryPath = "${config.home.profileDirectory}/bin/claude";
              customModels = [];
              launchArgs = "";
            };
            driver = "claudeAgent";
            enabled = true;
          };
          codex = {
            accentColor = "#0891b2";
            config = {
              binaryPath = "codex";
              customModels = [];
              # Codex keeps its native provider here, not the gateway ai-proxy/clients.nix routes other clients to.
              launchArgs = "-c model_provider=\"openai\"";
            };
            driver = "codex";
            enabled = true;
          };
          grok = {
            config = {
              binaryPath = "grok";
              customModels = [];
            };
            driver = "grok";
            enabled = false;
          };
          opencode = {
            config = {
              binaryPath = "opencode";
              customModels = [];
            };
            driver = "opencode";
            enabled = false;
          };
        };
        providers = {
          cursor = {
            enabled = false;
          };
          grok = {
            enabled = false;
          };
          opencode = {
            enabled = false;
          };
        };
        sourceControlWriterModelSelection = {
          instanceId = "codex";
          model = "gpt-5.6-luna";
          options = [
            {
              id = "reasoningEffort";
              value = "low";
            }
            {
              id = "serviceTier";
              value = "default";
            }
          ];
        };
        usagePriceOverrides = {
          gpt-6-astra = {
            cacheReadCostPerMillionTokens = 1;
            cacheWriteCostPerMillionTokens = 12.5;
            inputCostPerMillionTokens = 10;
            outputCostPerMillionTokens = 50;
          };
        };
      };
      keybindings =
        sharedKeybindings
        ++ [
          # Nightly-only additions on top of the bindings shared with the dev profile.
          {
            command = "filePicker.toggle";
            key = "mod+p";
            when = "!terminalFocus";
          }
          {
            command = "projectSearch.toggle";
            key = "mod+shift+f";
            when = "!terminalFocus";
          }
          {
            command = "themeEditor.toggle";
            key = "mod+alt+shift+t";
          }
          {
            command = "composer.stash";
            key = "mod+s";
            when = "!terminalFocus";
          }
          {
            command = "thread.settle";
            key = "mod+shift+s";
            when = "!terminalFocus";
          }
          {
            command = "thread.pin";
            key = "mod+shift+p";
            when = "!terminalFocus";
          }
          {
            command = "thread.copyReference";
            key = "mod+shift+c";
            when = "!terminalFocus";
          }
          {
            command = "rightPanel.close";
            key = "mod+w";
            when = "!terminalFocus";
          }
        ];
      clientSettings = {
        appearanceContrast = 100;
        browserAutoShowFloatingPreview = true;
        browserDefaultAppearance = "system";
        browserDefaultViewport = {
          _tag = "fill";
        };
        browserDefaultZoomFactor = 1;
        browserLinkTarget = "system";
        browserRecordingFrameRate = 30;
        composerCollapseOnScroll = true;
        confirmQuit = "hold";
        confirmThreadArchive = false;
        confirmThreadDelete = true;
        confirmThreadUnpin = false;
        contextWindowMeterEnabled = false;
        diffColorScheme = "red-green";
        diffIgnoreWhitespace = true;
        diffLayout = "stacked";
        environmentIdentificationMode = "artwork";
        fontFamilyCode = "";
        fontFamilyComposer = "";
        fontFamilySans = "ComicCodeLigatures Nerd Font";
        fontFamilyTerminal = "";
        fontSizeCode = 13;
        fontSizeInterface = 15;
        fontSizePrompt = 14;
        fontSizeTerminal = 12;
        fontSmoothing = true;
        glassOpacity = 80;
        legacySidebarEnabled = false;
        loadBalancingEnabled = false;
        loadBalancingWeights = {};
        panelAnimationDurationMs = 0;
        planModeEnabled = false;
        proactivePanelsEnabled = false;
        providerModelPreferences = {};
        pullRequestMergeMethodOverrides = {};
        showSkillsInSlashMenu = true;
        sidebarProjectGroupingMode = "repository";
        sidebarProjectGroupingOverrides = {};
        sidebarProjectSortOrder = "updated_at";
        sidebarThreadPreviewCount = 6;
        sidebarThreadSortOrder = "updated_at";
        snapShotAnimations = true;
        snapShotEnabled = false;
        snapShotFlash = true;
        snapShotIncludeAccessibility = true;
        snapShotPlaySound = true;
        snapShotShortcut = {
          kind = "both-shift-keys";
        };
        snapShotSound = "soft-pop";
        timestampFormat = "locale";
        wordWrap = true;
      };
    };
  };
}
