{inputs, ...}: {
  home.lisa-asterion = {
    lib,
    pkgs,
    ...
  }: let
    chatgpt = pkgs.chatgpt.override {codex = null;};
    webcord = pkgs.webcord.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          printf '%s\n' '${builtins.toJSON {
            type = "release";
            features.updateNotifications = false;
          }}' > "$out/lib/node_modules/webcord/buildInfo.json"
        '';
    });
    helium = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
    icons = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps";
    slack = pkgs.writeShellApplication {
      name = "asterion-slack";
      text = ''exec ${lib.getExe helium} --app=https://app.slack.com/client "$@"'';
    };
    spotify = pkgs.writeShellApplication {
      name = "asterion-spotify";
      text = ''exec ${lib.getExe pkgs.ghostty} --title=Spotify -e ${lib.getExe pkgs.spotaui} "$@"'';
    };
    codex = pkgs.writeShellApplication {
      name = "asterion-codex";
      text = ''exec ${lib.getExe pkgs.ghostty} --title=Codex -e ${lib.getExe pkgs.codex} "$@"'';
    };
  in {
    home.packages = [
      chatgpt
      webcord
      slack
      spotify
      codex
      pkgs.papers
      pkgs.loupe
      pkgs.file-roller
      pkgs.gnome-calculator
    ];

    xdg.desktopEntries = {
      webcord = {
        name = "Discord (WebCord)";
        genericName = "Discord client";
        exec = lib.getExe webcord;
        icon = "webcord";
        categories = ["Network" "InstantMessaging"];
      };
      asterion-calendar = {
        name = "Calendar";
        genericName = "Thunderbird calendar";
        exec = "${lib.getExe pkgs.thunderbird} -calendar";
        icon = "x-office-calendar";
        categories = ["Office" "Calendar"];
      };
      asterion-slack = {
        name = "Slack";
        genericName = "Slack web app";
        exec = lib.getExe slack;
        icon = "${icons}/slack.svg";
        categories = ["Network" "InstantMessaging"];
      };
      asterion-spotify = {
        name = "Spotify (Spotatui)";
        genericName = "Spotify terminal player";
        exec = lib.getExe spotify;
        icon = "${icons}/spotify.svg";
        categories = ["AudioVideo" "Audio" "Player"];
      };
      asterion-codex = {
        name = "Codex CLI";
        genericName = "Coding agent in Ghostty";
        exec = lib.getExe codex;
        icon = "utilities-terminal";
        categories = ["Development"];
      };
    };
    xdg.mimeApps.defaultApplications = {
      "application/pdf" = ["org.gnome.Papers.desktop"];
      "image/jpeg" = ["org.gnome.Loupe.desktop"];
      "image/png" = ["org.gnome.Loupe.desktop"];
      "image/webp" = ["org.gnome.Loupe.desktop"];
      "application/zip" = ["org.gnome.FileRoller.desktop"];
    };
  };
}
