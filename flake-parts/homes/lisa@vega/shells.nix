{
  config,
  pkgs,
  ...
}: let
  homeDirectory = config.home.homeDirectory;
  nomShellFunctions = ''
    nix() {
      if [ "$#" -eq 0 ]; then
        command nix
        return
      fi

      case "$1" in
        build|shell|develop)
          command nom "$@"
          ;;
        *)
          command nix "$@"
          ;;
      esac
    }

    nix-build() {
      command nom-build "$@"
    }

    nix-shell() {
      command nom-shell "$@"
    }
  '';
in {
  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "code --wait";
    VISUAL = "code --wait";
    SSH_AUTH_SOCK = "${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      codex-yolo = "codex --yolo";
    };
    initExtra = nomShellFunctions;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      codex-yolo = "codex --yolo";
    };
    initContent = nomShellFunctions;
    oh-my-zsh = {
      enable = true;
      plugins = ["git" "docker" "kubectl"];
      theme = "robbyrussell";
    };
    dotDir = "${config.xdg.configHome}/zsh";
  };

  programs.nushell = {
    enable = true;
    plugins = with pkgs.nushellPlugins; [
      polars
      formats
      gstat
      query
      #semver
    ];
    settings.show_banner = false;
    extraEnv = ''
      $env.PATH = ([
        "/etc/profiles/per-user/${config.home.username}/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
      ] | append $env.PATH | uniq)

      alias codex-yolo = codex --yolo
    '';
    extraConfig = ''
      def --wrapped nix [...args: string] {
        if ($args | is-empty) {
          ^nix
          return
        }

        let command = ($args | first)

        if ($command in [build shell develop]) {
          ^nom ...$args
        } else {
          ^nix ...$args
        }
      }

      def --wrapped nix-build [...args: string] {
        ^nom-build ...$args
      }

      def --wrapped nix-shell [...args: string] {
        ^nom-shell ...$args
      }
    '';
  };
}
