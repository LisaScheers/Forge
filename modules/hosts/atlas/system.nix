{
  nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
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
      matrix-synapse.extraGroups = ["matrix-secrets"];
      turnserver.extraGroups = ["matrix-secrets"];
    };
    users.groups.matrix-secrets = {};

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    security.acme.acceptTerms = true;
    security.acme.defaults.email = "lisa@scheers.tech";

    age.secrets = {
      auto-sync-update-env = {
        file = ../../security/agenix/secrets/atlas/auto-sync-update-env.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      matrix-registration-secret = {
        file = ../../security/agenix/secrets/atlas/matrix-registration-secret.age;
        owner = "matrix-synapse";
        group = "matrix-synapse";
        mode = "0400";
      };
      matrix-turn-secret = {
        file = ../../security/agenix/secrets/atlas/matrix-turn-secret.age;
        owner = "root";
        group = "matrix-secrets";
        mode = "0440";
      };
    };

    services.autoSyncUpdate = {
      enable = true;
      flakeHost = "atlas";
      environmentFile = config.age.secrets.auto-sync-update-env.path;
    };

    matrix = {
      enable = true;
      rootDomain = "bylisa.dev";
      subDomain = "matrix";
      turnRealm = "turn.bylisa.dev";
      registrationSecretFile = config.age.secrets.matrix-registration-secret.path;
      turnSecretFile = config.age.secrets.matrix-turn-secret.path;
    };

    systemd.services = {
      nix-auto-sync-update.restartTriggers = [../../security/agenix/secrets/atlas/auto-sync-update-env.age];
      matrix-synapse.restartTriggers = [
        ../../security/agenix/secrets/atlas/matrix-registration-secret.age
        ../../security/agenix/secrets/atlas/matrix-turn-secret.age
      ];
      coturn.restartTriggers = [../../security/agenix/secrets/atlas/matrix-turn-secret.age];
    };

    # Preserve PostgreSQL 16 and /var/lib/postgresql/16 until a database migration.
    system.stateVersion = "25.05";
  };
}
