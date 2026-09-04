{config, ...}: {
  services.shop-empty-track = {
    enable = true;
    port = 3001;
    shopifyApiKey = "placeholder-will-be-overridden-by-env-file";
    shopifyApiSecret = "placeholder-will-be-overridden-by-env-file";
    shopifyAppUrl = "https://shop-empty-track.bylisa.dev";
    environmentFiles = [config.age.secrets.shop-empty-track-env.path];

    nginx = {
      enable = true;
      hostName = "shop-empty-track.bylisa.dev";
      enableACME = true;
      forceSSL = true;
    };
  };

  age.secrets.shop-empty-track-env = {
    file = ../../agenix/secrets/atlas/shop-empty-track-env.age;
    owner = "shop-empty-track";
    group = "shop-empty-track";
    mode = "0400";
  };

  systemd.services.shop-empty-track.restartTriggers = [../../agenix/secrets/atlas/shop-empty-track-env.age];
}
