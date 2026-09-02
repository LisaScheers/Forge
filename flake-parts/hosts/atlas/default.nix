{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./_hardware-configuration.nix
    ./minecraft.nix
    ./mastodon.nix
    ./monitoring.nix
    ./pony-tack.nix
    ./sl-remote.nix
    # ./shop-empty-track.nix
    ./authentik.nix
    ./bluesky-pds.nix
    ./disko-config.nix
    ./forgejo.nix
    ./html-communication.nix
  ];

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
      file = ../../agenix/secrets/atlas/auto-sync-update-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    matrix-registration-secret = {
      file = ../../agenix/secrets/atlas/matrix-registration-secret.age;
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0400";
    };
    matrix-turn-secret = {
      file = ../../agenix/secrets/atlas/matrix-turn-secret.age;
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
    nix-auto-sync-update.restartTriggers = [../../agenix/secrets/atlas/auto-sync-update-env.age];
    matrix-synapse.restartTriggers = [
      ../../agenix/secrets/atlas/matrix-registration-secret.age
      ../../agenix/secrets/atlas/matrix-turn-secret.age
    ];
    coturn.restartTriggers = [../../agenix/secrets/atlas/matrix-turn-secret.age];
  };

  system.stateVersion = "25.05";
}
