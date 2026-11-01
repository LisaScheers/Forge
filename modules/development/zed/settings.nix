{
  home.lisa = {
    programs.zed-editor.userSettings = {
      buffer_font_family = "ComicCodeLigatures Nerd Font";
      project_panel = {
        dock = "left";
      };
      agent = {
        sidebar_side = "right";
        dock = "right";
        tool_permissions.default = "allow";
        sandbox_permissions.allow_unsandboxed = true;
        default_model = {
          provider = "codex";
          model = "gpt-6-astra";
        };
      };
      vim_mode = false;
      accessible_mode = true;
      cli_default_open_behavior = "new_window";
      edit_predictions.provider = "copilot";
      git_panel = {
        group_by = "none";
        tree_view = true;
        dock = "left";
      };
      proxy = "";
      agent_servers = {
        github-copilot-cli.type = "registry";
        codex-acp.type = "registry";
      };
      load_direnv = "direct";
      base_keymap = "VSCode";
      autosave = "on_focus_change";
      format_on_save = "on";
      show_whitespaces = "trailing";
      ui_font_size = 14;
      buffer_font_size = 12;
    };
  };
}
