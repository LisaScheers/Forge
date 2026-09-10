{
  forge.modules.nixos.asterion = {pkgs, ...}: {
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
    };
    hardware.bluetooth.enable = true;
    hardware.graphics.enable = true;
    # Install the session and its portals/PAM integration, but keep console login
    # until Asahi M3 has a renderer supported by niri's DRM backend.
    programs.niri.enable = true;
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    fonts.packages = with pkgs; [dejavu_fonts noto-fonts noto-fonts-color-emoji];
    time.timeZone = "Europe/Brussels";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "ter-v32n";
      packages = [pkgs.terminus_font];
    };

    # M3's firmware framebuffer cannot resume from sleep yet (2026-09-07).
    systemd.sleep.settings.Sleep = {
      AllowSuspend = false;
      AllowHibernation = false;
      AllowSuspendThenHibernate = false;
      AllowHybridSleep = false;
    };
    services.logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
      HandleLidSwitchDocked = "lock";
    };

    users.users.lisa = {
      isNormalUser = true;
      description = "Lisa Scheers";
      extraGroups = ["wheel" "networkmanager"];
      shell = pkgs.zsh;
    };
    programs.zsh.enable = true;
    # Set Lisa's password with nixos-enter before the first reboot.
    users.users.root.hashedPassword = "!";

    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "lisa"];
      auto-optimise-store = true;
    };
    environment.systemPackages = with pkgs; [git vim curl pciutils usbutils];
    zramSwap.enable = true;
    system.stateVersion = "26.05";
  };
}
