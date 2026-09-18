{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
    systemd.services.authentik-watch-room-blueprint = {
      description = "Apply watch room Authentik provider and owner policy";
      requiredBy = ["authentik.service"];
      before = ["authentik.service"];
      after = ["authentik-migrate.service"];
      requires = ["authentik-migrate.service"];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        User = "authentik";
        StateDirectory = "authentik";
        WorkingDirectory = "%S/authentik";
        EnvironmentFile = [config.age.secrets.authentik-env.path];
        Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
        ExecStartPre = "${pkgs.coreutils}/bin/install -D -m 0600 ${../../../services/watch-room/authentik.yaml} %S/authentik/blueprints/watch-room.yaml";
        ExecStart = "${config.services.authentik.package}/bin/ak apply_blueprint watch-room.yaml";
        # Attach additively: preserve every existing embedded-outpost provider.
        ExecStartPost = ''${config.services.authentik.package}/bin/ak shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='Watch room host')); outpost.save()"'';
      };
      restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    };
  };
}
