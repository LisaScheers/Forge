{
  alternate_scroll = "off";
  blinking = "off";
  copy_on_select = false;
  dock = "bottom";
  detect_venv = {
    on = {
      directories = [
        ".env"
        "env"
        ".venv"
        "venv"
      ];
      activate_script = "default";
    };
  };
  env = {
    TERM = "ghostty";
  };
  font_family = "ComicCodeLigatures Nerd Font";
  working_directory = "current_project_directory";
}
