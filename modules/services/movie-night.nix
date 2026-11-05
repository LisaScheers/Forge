{
  config,
  inputs,
  ...
}: {
  flake-file.inputs.movie-night.url = "github:LisaScheers/movie-night/2b8e06fb40eaef4267f8986e408518dbf841f932";
  flake-file.nixConfig = {
    extra-substituters = ["https://kixelated.cachix.org"];
    extra-trusted-public-keys = ["kixelated.cachix.org-1:CmFcV0lyM6KuVM2m9mih0q4SrAa0XyCsiM7GHrz3KKk="];
  };
  flake.agenixRules."secrets/nook/movie-night-env.age".publicKeys = [
    config.secrets.pubkeys.users.lisa
    config.secrets.pubkeys.hosts.nook
  ];
  nixos.atlas = {config, ...}: {
    imports = [inputs.movie-night.nixosModules.atlas inputs.movie-night.nixosModules.authentik];
    services.movie-night-relay = {
      enable = true;
      domain = "watch.bylisa.dev";
      relayDomain = "moq.bylisa.dev";
      backendUrl = "http://100.106.233.104:3100";
      authentikUrl = "https://auth.bylisa.dev";
    };
    services.movie-night-authentik = {
      enable = true;
      domain = "watch.bylisa.dev";
      adminUsers = ["lisa"];
      environmentFile = config.age.secrets.authentik-env.path;
      manageCommand = "${config.services.authentik.authentikComponents.manage}/bin/manage.py";
    };
  };
  nixos.nook = {config, ...}: {
    imports = [inputs.movie-night.nixosModules.nook];
    age.secrets.movie-night-env.file = ../security/agenix/secrets/nook/movie-night-env.age;
    services.movie-night = {
      enable = true;
      environmentFile = config.age.secrets.movie-night-env.path;
      listenAddress = "100.106.233.104";
      origin = "https://watch.bylisa.dev";
      relayUrl = "https://moq.bylisa.dev";
      jellyfinUserId = "466f59ea028949cca3033f222ebec388";
      mediaRoots = ["/srv/disks/western-digital-hdd/media/library"];
      trustedProxies = ["100.87.26.75"];
      internalPeers = ["100.87.26.75"];
      adminUsers = ["lisa"];
      openTailscaleFirewall = true;
      vaapiDevice = "/dev/dri/renderD128";
      rooms = [
        {
          id = "movie-night";
          name = "Movie night";
          path = "/r/movie-night";
        }
        {
          id = "series-night";
          name = "Series night";
          path = "/series";
        }
      ];
    };
  };
}
