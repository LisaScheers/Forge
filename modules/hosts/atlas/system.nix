{
  nixos.atlas = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      git
      htop
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.trusted-users = ["lisa"];

    networking.domain = "bylisa.dev";

    # Leave a buffer for memory spikes from Minecraft and the shared services.
    swapDevices = [
      {
        device = "/var/swapfile";
        size = 8 * 1024;
      }
    ];

    boot.loader.grub = {
      enable = true;
      configurationLimit = 10;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    users.users = {
      root.hashedPassword = "!"; # Disable root login
      lisa = {
        hashedPassword = "!";
        isNormalUser = true;
        description = "Lisa user";
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFzIIn0D0sH6Pual0iAlciIDZo6T0qlWWCgRpQhq8U3"
        ];
      };
    };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    security.acme.acceptTerms = true;
    security.acme.defaults.email = "lisa@scheers.tech";

    system.stateVersion = "26.11";
  };
}
