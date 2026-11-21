{config, ...}: let
  features = config.nixos;
  secret = name: ../../security/agenix/secrets/atlas/${name}.age;
in {
  # Atlas hosts Synapse, coturn and the Discord bridge on its dedicated volume.
  nixos.atlas = {config, ...}: {
    imports = [features.matrix features.matrix-volume];

    forge.matrix = {
      enable = true;
      rootDomain = "bylisa.dev";
      subDomain = "matrix";
      turnRealm = "turn.bylisa.dev";
      registrationSecretFile = config.age.secrets.matrix-registration-secret.path;
      turnSecretFile = config.age.secrets.matrix-turn-secret.path;
      volume = {
        enable = true;
        device = "/dev/disk/by-id/scsi-0HC_Volume_107199635";
      };
    };

    services.matrix-synapse.settings = {
      enable_registration = true;
      registration_requires_token = true;
    };
    services.nginx.virtualHosts."${config.forge.matrix.subDomain}.${config.forge.matrix.rootDomain}".locations."/_matrix".extraConfig = ''
      client_max_body_size 512m;
    '';

    users.groups.matrix-secrets = {};
    users.users = {
      matrix-synapse.extraGroups = ["matrix-secrets"];
      turnserver.extraGroups = ["matrix-secrets"];
    };
    age.secrets = {
      matrix-registration-secret = {
        file = secret "matrix-registration-secret";
        owner = "matrix-synapse";
        group = "matrix-synapse";
        mode = "0400";
      };
      matrix-turn-secret = {
        file = secret "matrix-turn-secret";
        owner = "root";
        group = "matrix-secrets";
        mode = "0440";
      };
    };
    systemd.services = {
      matrix-synapse.restartTriggers = [
        (secret "matrix-registration-secret")
        (secret "matrix-turn-secret")
      ];
      coturn.restartTriggers = [(secret "matrix-turn-secret")];
    };
  };
}
