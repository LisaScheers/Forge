{
  home.lisa-vega.programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    # Leave unset options out: gh reads a YAML null as the string "null", so
    # http_unix_socket = null made every request dial a socket named "null".
    settings = {
      version = 1;
      git_protocol = "https";
      editor = "";
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      aliases = {
        co = "pr checkout";
      };
      color_labels = "disabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
    };
  };
}
