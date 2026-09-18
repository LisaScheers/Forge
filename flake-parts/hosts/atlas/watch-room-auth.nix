{
  forge.modules.nixos.atlas = {
    config,
    pkgs,
    ...
  }: {
    # Preserve the application host across both nginx hops so the embedded
    # outpost can select the matching forward-auth provider.
    services.nginx.virtualHosts."auth.bylisa.dev".locations."^~ /outpost.goauthentik.io/" = {
      proxyPass = "https://127.0.0.1:9443";
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
    };
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
        ExecStart = "${config.services.authentik.authentikComponents.manage}/bin/manage.py apply_blueprint watch-room.yaml";
        # Attach additively: preserve every existing embedded-outpost provider.
        ExecStartPost = ''${config.services.authentik.authentikComponents.manage}/bin/manage.py shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='Watch room host')); outpost.save()"'';
      };
      restartTriggers = [../../agenix/secrets/atlas/authentik-env.age];
    };
  };
}
