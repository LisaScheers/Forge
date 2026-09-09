{...}: {
  forge.modules.homeManager."lisa@asterion" = {
    lib,
    pkgs,
    ...
  }: let
    niriConfig = pkgs.replaceVars ./niri.kdl {
      foot = lib.getExe pkgs.foot;
      fuzzel = lib.getExe pkgs.fuzzel;
      swaylock = lib.getExe pkgs.swaylock;
      wpctl = lib.getExe' pkgs.wireplumber "wpctl";
      makoctl = lib.getExe' pkgs.mako "makoctl";
      xwayland-satellite = lib.getExe pkgs.xwayland-satellite;
      DEFAULT_AUDIO_SINK = null;
      DEFAULT_AUDIO_SOURCE = null;
    };
    lock = "${lib.getExe pkgs.swaylock} --daemonize";
  in {
    # Keep native KDL in Home Manager and validate it with the installed niri.
    xdg.configFile."niri/config.kdl".source = pkgs.runCommand "asterion-niri-config" {} ''
      ${lib.getExe pkgs.niri} validate --config ${niriConfig}
      cp ${niriConfig} $out
    '';

    home.packages = with pkgs; [
      niri
      mako
      swaybg
      xwayland-satellite
      wl-clipboard
      wireplumber
      pavucontrol
      networkmanagerapplet
      nautilus
    ];
    home.sessionVariables.NIXOS_OZONE_WL = "1";
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "DejaVu Sans Mono:size=11";
          pad = "10x10";
        };
        colors = {
          background = "000000";
          foreground = "ffffff";
        };
      };
    };
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          terminal = "${lib.getExe pkgs.foot}";
          font = "DejaVu Sans:size=11";
          width = 40;
          lines = 10;
        };
        colors = {
          background = "000000ff";
          text = "ffffffff";
          match = "ffffffff";
          selection = "222222ff";
          selection-text = "ffffffff";
          selection-match = "ffffffff";
          border = "ffffffff";
        };
        border = {
          width = 1;
          radius = 0;
        };
      };
    };

    programs.swaylock = {
      enable = true;
      settings = {
        color = "000000";
        font = "DejaVu Sans";
        indicator-radius = 60;
        indicator-thickness = 2;
        inside-color = "000000";
        ring-color = "ffffff";
        line-color = "000000";
        key-hl-color = "aaaaaa";
        text-color = "ffffff";
        show-failed-attempts = true;
        ignore-empty-password = true;
      };
    };
    services.swayidle = {
      enable = true;
      systemdTargets = ["graphical-session.target"];
      timeouts = [
        {
          timeout = 300;
          command = lock;
        }
      ];
      events = {
        lock = lock;
        before-sleep = lock;
      };
      # No suspend or monitor-power timeout: M3's framebuffer cannot resume yet.
    };
    services.polkit-gnome.enable = true;
    services.mako = {
      enable = true;
      # Install the package above, with our systemd-aware D-Bus activation below.
      package = null;
      settings = {
        font = "DejaVu Sans 10";
        background-color = "#000000";
        text-color = "#ffffff";
        border-color = "#ffffff";
        border-size = 1;
        border-radius = 0;
        width = 340;
        margin = 10;
        padding = 12;
        default-timeout = 5000;
        max-visible = 4;
        anchor = "top-right";
        "urgency=critical".default-timeout = 0;
      };
    };

    # Route D-Bus activation through the same session-bound unit, so early
    # notifications cannot start a second, unmanaged Mako process.
    xdg.dataFile."dbus-1/services/org.freedesktop.Notifications.service".text = ''
      [D-BUS Service]
      Name=org.freedesktop.Notifications
      Exec=${lib.getExe pkgs.mako}
      SystemdService=mako.service
    '';

    systemd.user.services = {
      # This Home Manager revision has no swaybg module.
      swaybg = {
        Unit = {
          Description = "Asterion desktop background";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.swaybg} --color '#000000'";
          Restart = "on-failure";
        };
        Install.WantedBy = ["graphical-session.target"];
      };
      mako = {
        Unit = {
          Description = "Mako notification daemon";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = lib.getExe pkgs.mako;
          Restart = "on-failure";
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    };

    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        targets = ["graphical-session.target"];
      };
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 12;
        modules-left = ["custom/hostname" "niri/workspaces"];
        modules-center = ["niri/window"];
        modules-right = ["tray" "network" "pulseaudio" "battery" "clock"];
        "custom/hostname" = {
          format = "ASTERION";
          tooltip = false;
        };
        "niri/workspaces" = {format = "{name}";};
        "niri/window" = {max-length = 50;};
        tray.spacing = 8;
        network = {
          format-wifi = "Wi-Fi {signalStrength}%";
          format-ethernet = "Ethernet";
          format-disconnected = "Offline";
          tooltip-format = "{ifname}: {ipaddr}";
          on-click = "${lib.getExe pkgs.foot} ${lib.getExe' pkgs.networkmanager "nmtui"}";
        };
        pulseaudio = {
          format = "vol {volume}%";
          format-muted = "muted";
          on-click = lib.getExe pkgs.pavucontrol;
        };
        battery = {
          format = "{capacity}%";
          format-charging = "+{capacity}%";
          states = {
            warning = 20;
            critical = 10;
          };
        };
        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%A, %d %B %Y}";
        };
      };
      style = ''
        * {
          font-family: "DejaVu Sans", sans-serif;
          font-size: 12px;
          border: none;
          border-radius: 0;
          min-height: 0;
          box-shadow: none;
          text-shadow: none;
        }
        window#waybar {
          background: #000000;
          color: #ffffff;
          border-bottom: 1px solid #333333;
        }
        #custom-hostname { padding-left: 12px; }
        #clock { padding-right: 12px; }
        #workspaces button { color: #999999; padding: 0 8px; }
        #workspaces button.active { color: #ffffff; border-bottom: 1px solid #ffffff; }
        #workspaces button:hover { background: #222222; }
        #window { color: #aaaaaa; }
        #battery.warning { color: #e0bd7c; }
        #battery.critical { color: #ff8080; }
        tooltip { background: #000000; color: #ffffff; border: 1px solid #ffffff; }
      '';
    };
  };
}
