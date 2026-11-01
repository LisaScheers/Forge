{
  config,
  inputs,
  ...
}: {
  home.lisa-cli.imports = [config.home.t3-code];
  home.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  home.lisa-vega = {
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
      ".t3/dev/keybindings.json".settings = [
        {
          command = "sidebar.toggle";
          key = "mod+b";
        }
        {
          command = "terminal.toggle";
          key = "mod+j";
        }
        {
          command = "rightPanel.toggle";
          key = "mod+alt+b";
        }
        {
          command = "terminal.split";
          key = "mod+d";
          when = "terminalFocus";
        }
        {
          command = "terminal.splitVertical";
          key = "mod+shift+d";
          when = "terminalFocus";
        }
        {
          command = "terminal.new";
          key = "mod+n";
          when = "terminalFocus";
        }
        {
          command = "terminal.close";
          key = "mod+w";
          when = "terminalFocus";
        }
        {
          command = "diff.toggle";
          key = "mod+d";
          when = "!terminalFocus";
        }
        {
          command = "preview.toggle";
          key = "mod+shift+j";
        }
        {
          command = "preview.refresh";
          key = "mod+r";
          when = "previewFocus";
        }
        {
          command = "preview.focusUrl";
          key = "mod+l";
          when = "previewFocus";
        }
        {
          command = "preview.zoomIn";
          key = "mod+=";
          when = "previewFocus";
        }
        {
          command = "preview.zoomIn";
          key = "mod++";
          when = "previewFocus";
        }
        {
          command = "preview.zoomOut";
          key = "mod+-";
          when = "previewFocus";
        }
        {
          command = "preview.resetZoom";
          key = "mod+0";
          when = "previewFocus";
        }
        {
          command = "commandPalette.toggle";
          key = "mod+k";
          when = "!terminalFocus";
        }
        {
          command = "chat.new";
          key = "mod+n";
          when = "!terminalFocus";
        }
        {
          command = "chat.new";
          key = "mod+shift+o";
          when = "!terminalFocus";
        }
        {
          command = "chat.newLocal";
          key = "mod+shift+n";
          when = "!terminalFocus";
        }
        {
          command = "modelPicker.toggle";
          key = "mod+shift+m";
          when = "!terminalFocus";
        }
        {
          command = "editor.openFavorite";
          key = "mod+o";
        }
        {
          command = "thread.previous";
          key = "mod+shift+[";
        }
        {
          command = "thread.next";
          key = "mod+shift+]";
        }
        {
          command = "thread.jump.1";
          key = "mod+1";
        }
        {
          command = "thread.jump.2";
          key = "mod+2";
        }
        {
          command = "thread.jump.3";
          key = "mod+3";
        }
        {
          command = "thread.jump.4";
          key = "mod+4";
        }
        {
          command = "thread.jump.5";
          key = "mod+5";
        }
        {
          command = "thread.jump.6";
          key = "mod+6";
        }
        {
          command = "thread.jump.7";
          key = "mod+7";
        }
        {
          command = "thread.jump.8";
          key = "mod+8";
        }
        {
          command = "thread.jump.9";
          key = "mod+9";
        }
        {
          command = "modelPicker.jump.1";
          key = "mod+1";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.2";
          key = "mod+2";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.3";
          key = "mod+3";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.4";
          key = "mod+4";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.5";
          key = "mod+5";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.6";
          key = "mod+6";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.7";
          key = "mod+7";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.8";
          key = "mod+8";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.9";
          key = "mod+9";
          when = "modelPickerOpen";
        }
      ];
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
              binaryPath = "";
              customModels = [];
            };
            driver = "antigravity";
            enabled = false;
          };
          claudeAgent = {
            config = {
              binaryPath = "claude";
              customModels = [];
              launchArgs = "";
            };
            driver = "claudeAgent";
            enabled = false;
          };
          codex = {
            accentColor = "#0891b2";
            config = {
              binaryPath = "codex";
              customModels = [];
              launchArgs = "";
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
      keybindings = [
        {
          command = "sidebar.toggle";
          key = "mod+b";
        }
        {
          command = "terminal.toggle";
          key = "mod+j";
        }
        {
          command = "rightPanel.toggle";
          key = "mod+alt+b";
        }
        {
          command = "terminal.split";
          key = "mod+d";
          when = "terminalFocus";
        }
        {
          command = "terminal.splitVertical";
          key = "mod+shift+d";
          when = "terminalFocus";
        }
        {
          command = "terminal.new";
          key = "mod+n";
          when = "terminalFocus";
        }
        {
          command = "terminal.close";
          key = "mod+w";
          when = "terminalFocus";
        }
        {
          command = "diff.toggle";
          key = "mod+d";
          when = "!terminalFocus";
        }
        {
          command = "preview.toggle";
          key = "mod+shift+j";
        }
        {
          command = "preview.refresh";
          key = "mod+r";
          when = "previewFocus";
        }
        {
          command = "preview.focusUrl";
          key = "mod+l";
          when = "previewFocus";
        }
        {
          command = "preview.zoomIn";
          key = "mod+=";
          when = "previewFocus";
        }
        {
          command = "preview.zoomIn";
          key = "mod++";
          when = "previewFocus";
        }
        {
          command = "preview.zoomOut";
          key = "mod+-";
          when = "previewFocus";
        }
        {
          command = "preview.resetZoom";
          key = "mod+0";
          when = "previewFocus";
        }
        {
          command = "commandPalette.toggle";
          key = "mod+k";
          when = "!terminalFocus";
        }
        {
          command = "chat.new";
          key = "mod+n";
          when = "!terminalFocus";
        }
        {
          command = "chat.new";
          key = "mod+shift+o";
          when = "!terminalFocus";
        }
        {
          command = "chat.newLocal";
          key = "mod+shift+n";
          when = "!terminalFocus";
        }
        {
          command = "modelPicker.toggle";
          key = "mod+shift+m";
          when = "!terminalFocus";
        }
        {
          command = "editor.openFavorite";
          key = "mod+o";
        }
        {
          command = "thread.previous";
          key = "mod+shift+[";
        }
        {
          command = "thread.next";
          key = "mod+shift+]";
        }
        {
          command = "thread.jump.1";
          key = "mod+1";
        }
        {
          command = "thread.jump.2";
          key = "mod+2";
        }
        {
          command = "thread.jump.3";
          key = "mod+3";
        }
        {
          command = "thread.jump.4";
          key = "mod+4";
        }
        {
          command = "thread.jump.5";
          key = "mod+5";
        }
        {
          command = "thread.jump.6";
          key = "mod+6";
        }
        {
          command = "thread.jump.7";
          key = "mod+7";
        }
        {
          command = "thread.jump.8";
          key = "mod+8";
        }
        {
          command = "thread.jump.9";
          key = "mod+9";
        }
        {
          command = "modelPicker.jump.1";
          key = "mod+1";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.2";
          key = "mod+2";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.3";
          key = "mod+3";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.4";
          key = "mod+4";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.5";
          key = "mod+5";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.6";
          key = "mod+6";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.7";
          key = "mod+7";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.8";
          key = "mod+8";
          when = "modelPickerOpen";
        }
        {
          command = "modelPicker.jump.9";
          key = "mod+9";
          when = "modelPickerOpen";
        }
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
