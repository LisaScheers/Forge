{
  home.lisa-asterion = {
    programs.codex.settings = {
      model = "gpt-6.1-sol";
      model_reasoning_effort = "high";
      desktop = {
        conversationDetailMode = "STEPS_COMMANDS";
        sansFontSize = 12;
        codeFontSize = 11;
        "ambient-suggestions-enabled" = false;
        followUpQueueMode = "queue";
        "show-context-window-usage" = true;
        "open-local-url-in-target-preference" = "external-browser";
        "enabled-reasoning-efforts" = ["low" "medium" "high" "xhigh" "ultra" "max"];
        "show-ultra-in-model-picker-slider" = false;
        "open-in-target-preferences".global = "zed";
      };
      projects."/etc/nixos/forge".trust_level = "trusted";
    };
  };
}
