{
  config,
  inputs,
  ...
}: let
  inherit (config.network) atlas nook;
  # The MoQ relay comes prebuilt from kixelated's cache. Configure it for the
  # host that rebuilds atlas itself and for vega, which deploys it, rather than
  # as flake nixConfig, which Nix ignores unless the flake is trusted.
  kixelatedCache.nix.settings = {
    extra-substituters = ["https://kixelated.cachix.org"];
    extra-trusted-public-keys = ["kixelated.cachix.org-1:CmFcV0lyM6KuVM2m9mih0q4SrAa0XyCsiM7GHrz3KKk="];
  };
in {
  flake-file.inputs.movie-night.url = "github:LisaScheers/movie-night";
  darwin.vega = kixelatedCache;
  nixos.atlas = {
    config,
    options,
    ...
  }: {
    imports = [kixelatedCache inputs.movie-night.nixosModules.atlas inputs.movie-night.nixosModules.authentik];
    services.movie-night-relay = {
      enable = true;
      # moq-relay lacks meta.mainProgram, which the module's lib.getExe needs.
      # Only meta changes, so the store path and the kixelated cache hit stay the same.
      package = let
        relay = options.services.movie-night-relay.package.default;
      in
        relay // {meta = relay.meta // {mainProgram = "moq-relay";};};
      domain = "watch.bylisa.dev";
      relayDomain = "moq.bylisa.dev";
      backendUrl = "http://${nook.tailscale}:3100";
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
      listenAddress = nook.tailscale;
      origin = "https://watch.bylisa.dev";
      relayUrl = "https://moq.bylisa.dev";
      jellyfinUserId = "466f59ea028949cca3033f222ebec388";
      mediaRoots = ["/srv/disks/western-digital-hdd/media/library"];
      trustedProxies = [atlas.tailscale];
      internalPeers = [atlas.tailscale];
      adminUsers = ["lisa"];
      openTailscaleFirewall = true;
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
