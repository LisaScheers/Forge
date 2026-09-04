{config, ...}: let
  hostName = "sl-remote.bylisa.dev";
in {
  age.secrets.sl-remote-credentials = {
    file = ../../agenix/secrets/atlas/sl-remote-credentials.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.sl-remote = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 8788;
    publicUrl = "https://${hostName}";
    credentialsFile = config.age.secrets.sl-remote-credentials.path;
    dataDir = "/var/lib/sl-remote";
    historyRetentionDays = 7;
    maxDevices = 64;

    reverseProxy = {
      enable = true;
      provider = "nginx";
      inherit hostName;
      enableACME = true;
      acmeEmail = "lisa@scheers.tech";
      openFirewall = false;
    };
  };

  systemd.services.sl-remote.restartTriggers = [
    ../../agenix/secrets/atlas/sl-remote-credentials.age
  ];
}
