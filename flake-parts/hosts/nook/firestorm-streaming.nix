{pkgs, ...}: let
  lanAddress = "192.168.111.2";
  lanInterface = "enp7s0";
  audioSink = "Firestorm-Output";
  firestorm = pkgs.callPackage ../../_packages/firestorm.nix {};

  openboxConfig = pkgs.runCommand "openbox-firestorm-rc.xml" {} ''
    substitute ${pkgs.openbox}/etc/xdg/openbox/rc.xml "$out" \
      --replace-fail 'button="A-' 'button="W-'
  '';
in {
  users.users.firestorm = {
    isNormalUser = true;
    description = "Firestorm streaming session";
    home = "/var/lib/firestorm";
    createHome = true;
    hashedPassword = "!";
    extraGroups = [
      "audio"
      "input"
      "render"
      "uinput"
      "video"
    ];
  };

  environment = {
    systemPackages = [firestorm];

    # Firestorm uses Alt+drag for its camera, so reserve Super+drag for Openbox.
    etc."xdg/openbox/rc.xml".source = openboxConfig;
  };

  services.xserver = {
    # The RX 480 needs a connected display or HDMI/DisplayPort dummy plug for EDID.
    enable = true;
    videoDrivers = ["amdgpu"];
    windowManager.openbox.enable = true;

    displayManager = {
      lightdm = {
        enable = true;
        greeter.enable = false;
      };

      sessionCommands = ''
        output="$(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gawk}/bin/awk '$2 == "connected" { print $1; exit }')"
        if [ -n "$output" ]; then
          ${pkgs.xrandr}/bin/xrandr --output "$output" --mode 1920x1200 --rate 60 2>/dev/null \
            || ${pkgs.xrandr}/bin/xrandr --output "$output" --mode 1920x1080 --rate 60 2>/dev/null \
            || true
        fi

        ${pkgs.xset}/bin/xset s off
        ${pkgs.xset}/bin/xset -dpms
      '';
    };

    serverFlagsSection = ''
      Option "BlankTime" "0"
      Option "StandbyTime" "0"
      Option "SuspendTime" "0"
      Option "OffTime" "0"
    '';
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "firestorm";
    };
    defaultSession = "none+openbox";
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

    extraConfig.pipewire."91-firestorm-null-sink" = {
      "context.objects" = [
        {
          factory = "spa-node-factory";
          args = {
            "factory.name" = "support.node.driver";
            "node.name" = "Dummy-Driver";
            "priority.driver" = 8000;
          };
        }
        {
          factory = "adapter";
          args = {
            "factory.name" = "support.null-audio-sink";
            "node.name" = audioSink;
            "node.description" = "Firestorm Output";
            "media.class" = "Audio/Sink";
            "audio.position" = "FL,FR";
          };
        }
      ];
    };
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = false;
    openFirewall = false;

    settings = {
      sunshine_name = "nook";
      address_family = "ipv4";
      bind_address = lanAddress;
      upnp = "disabled";
      origin_web_ui_allowed = "lan";
      csrf_allowed_origins = "https://${lanAddress}:47990";
      lan_encryption_mode = 2;

      capture = "x11";
      encoder = "vaapi";
      hevc_mode = 1;
      av1_mode = 1;

      audio_sink = audioSink;
      stream_audio = "enabled";
    };

    applications = {
      env.PULSE_SINK = audioSink;
      apps = [
        {
          name = "Desktop";
        }
        {
          name = "Firestorm";
          cmd = "${firestorm}/bin/firestorm";
        }
      ];
    };
  };

  systemd.user.services.sunshine.environment.LIBVA_DRIVER_NAME = "radeonsi";

  networking.firewall.interfaces.${lanInterface} = {
    allowedTCPPorts = [
      47984
      47989
      47990
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };
}
