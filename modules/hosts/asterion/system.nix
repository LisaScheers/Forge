{
  nixos.asterion = {pkgs, ...}: let
    mesa = pkgs.callPackage ../../../packages/asterion-gpu-test-mesa/package.nix {};
    session = pkgs.callPackage ../../../packages/asterion-gpu-session/package.nix {
      inherit mesa;
      installed = true;
    };
    palette = (builtins.fromJSON (builtins.readFile ../../../packages/asterion-gpu-session/palette.json)).dark;
    greeter = pkgs.writeShellApplication {
      name = "asterion-greeter";
      runtimeInputs = [pkgs.coreutils pkgs.dbus];
      text = ''
        ${session.mesaEnvironment}
        exec ${pkgs.noctalia-greeter}/bin/noctalia-greeter-session "$@"
      '';
    };
  in {
    hardware.asahi = {
      enable = true;
      peripheralFirmwareDirectory = pkgs.asahi-firmware-j516s;
    };
    # Firmware is fetched from pinned Apple archive ranges; no /boot impurity.

    boot.loader.systemd-boot = {
      enable = true;
      # Asahi's ESP is small and also holds the vendor firmware archive.
      configurationLimit = 3;
    };
    boot.loader.efi.canTouchEfiVariables = false;

    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      settings.device."wifi.iwd.autoconnect" = false;
    };
    hardware.bluetooth.enable = true;
    hardware.graphics.enable = true;
    programs.niri.enable = true;
    services.displayManager = {
      sessionPackages = [session];
      noctalia-greeter = {
        enable = true;
        cursorTheme = {
          package = pkgs.vanilla-dmz;
          name = "DMZ-White";
        };
        settings = {
          user.default = "lisa";
          session.default = "Asterion";
          keyboard.layout = "us";
          cursor.size = 24;
          output = {
            name = "eDP-1";
            scale = 2;
            use_synced_settings = false;
          };
          idle.timeout = 0;
          appearance = {
            scheme = "Synced";
            theme_mode = "dark";
            corner_radius_scale = 0.0;
            font_family = "DejaVu Sans";
            wallpaper.fill_color = "#000000";
            palette = {
              primary = palette.mPrimary;
              on_primary = palette.mOnPrimary;
              secondary = palette.mSecondary;
              on_secondary = palette.mOnSecondary;
              tertiary = palette.mTertiary;
              on_tertiary = palette.mOnTertiary;
              error = palette.mError;
              on_error = palette.mOnError;
              surface = palette.mSurface;
              on_surface = palette.mOnSurface;
              surface_variant = palette.mSurfaceVariant;
              on_surface_variant = palette.mOnSurfaceVariant;
              outline = palette.mOutline;
              shadow = palette.mShadow;
              hover = palette.mHover;
              on_hover = palette.mOnHover;
            };
          };
        };
      };
    };
    services.greetd = {
      enable = true;
      settings.default_session = {
        user = "greeter";
        command = "${greeter}/bin/asterion-greeter";
      };
    };
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    fonts.packages = with pkgs; [dejavu_fonts noto-fonts noto-fonts-color-emoji];
    time.timeZone = "Europe/Brussels";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "ter-v32n";
      packages = [pkgs.terminus_font];
    };

    # Native GPU/display suspend and resume have not been qualified.
    systemd.sleep.settings.Sleep = {
      AllowSuspend = false;
      AllowHibernation = false;
      AllowSuspendThenHibernate = false;
      AllowHybridSleep = false;
    };
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    users.users.lisa = {
      isNormalUser = true;
      description = "Lisa Scheers";
      extraGroups = ["wheel" "networkmanager"];
      shell = pkgs.zsh;
    };
    programs.zsh.enable = true;
    # Preserve the existing password when replacing the system generation.
    users.users.root.hashedPassword = "!";
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
    users.users.root.openssh.authorizedKeys.keyFiles = [../../security/ssh/asterion/public-keys/vega.pub];
    users.users.lisa.openssh.authorizedKeys.keyFiles = [../../security/ssh/asterion/public-keys/vega.pub];

    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "lisa"];
      auto-optimise-store = true;
    };
    environment.systemPackages = with pkgs; [git vim curl pciutils usbutils firefox mpv session];
    zramSwap.enable = true;
    system.stateVersion = "26.11";
  };
}
