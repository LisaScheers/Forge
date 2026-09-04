{
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      format = builtins.concatStringsSep "" [
        "[](peach)"
        "$os"
        "$username"
        "[](bg:yellow fg:peach)"
        "$directory"
        "[](fg:yellow bg:teal)"
        "$git_branch"
        "$git_status"
        "[](fg:teal bg:blue)"
        "$c"
        "$cpp"
        "$rust"
        "$golang"
        "$nodejs"
        "$php"
        "$java"
        "$kotlin"
        "$haskell"
        "$python"
        "[](fg:blue bg:surface2)"
        "$docker_context"
        "$conda"
        "$pixi"
        "[](fg:surface2 bg:surface0)"
        "$time"
        "[ ](fg:surface0)"
        "$line_break$character"
      ];

      os = {
        disabled = false;
        style = "bg:peach fg:base";

        symbols = {
          Windows = "󰍲";
          Ubuntu = "󰕈";
          SUSE = "";
          Raspbian = "󰐿";
          Mint = "󰣭";
          Macos = "󰀵";
          Manjaro = "";
          Linux = "󰌽";
          Gentoo = "󰣨";
          Fedora = "󰣛";
          Alpine = "";
          Amazon = "";
          Android = "";
          Arch = "󰣇";
          Artix = "󰣇";
          EndeavourOS = "";
          CentOS = "";
          Debian = "󰣚";
          Redhat = "󱄛";
          RedHatEnterprise = "󱄛";
          Pop = "";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:peach fg:base";
        style_root = "bg:peach fg:base";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:base bg:yellow";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";

        substitutions = {
          Documents = "󰈙 ";
          Downloads = " ";
          Music = "󰝚 ";
          Pictures = " ";
          Developer = "󰲋 ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:teal";
        format = "[[ $symbol $branch ](fg:base bg:teal)]($style)";
      };

      git_status = {
        style = "bg:teal";
        format = "[[($all_status$ahead_behind )](fg:base bg:teal)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      cpp = {
        symbol = " ";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      java = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      kotlin = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      haskell = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      python = {
        symbol = "";
        style = "bg:blue";
        format = "[[ $symbol( $version) ](fg:base bg:blue)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:surface2";
        format = "[[ $symbol( $context) ](fg:sapphire bg:surface2)]($style)";
      };

      conda = {
        style = "bg:surface2";
        format = "[[ $symbol( $environment) ](fg:sapphire bg:surface2)]($style)";
      };

      pixi = {
        style = "bg:surface2";
        format = "[[ $symbol( $version)( $environment) ](fg:text bg:surface2)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:surface0";
        format = "[[  $time ](fg:text bg:surface0)]($style)";
      };

      line_break.disabled = false;

      character = {
        disabled = false;
        success_symbol = "[](bold fg:green)";
        error_symbol = "[](bold fg:red)";
        vimcmd_symbol = "[](bold fg:green)";
        vimcmd_replace_one_symbol = "[](bold fg:mauve)";
        vimcmd_replace_symbol = "[](bold fg:mauve)";
        vimcmd_visual_symbol = "[](bold fg:yellow)";
      };
    };
  };
}
