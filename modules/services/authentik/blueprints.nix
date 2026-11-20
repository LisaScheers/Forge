{
  nixos.atlas = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkOption types;
    inherit (config.forge.authentik) manage;
    # Attach additively, so every other embedded-outpost provider stays.
    attachToEmbeddedOutpost = provider: ''${manage} shell -c "from authentik.outposts.models import Outpost; from authentik.providers.proxy.models import ProxyProvider; outpost = Outpost.objects.get(managed='goauthentik.io/outposts/embedded'); outpost.providers.add(ProxyProvider.objects.get(name='${provider}')); outpost.save()"'';
    unit = blueprint: {
      inherit (blueprint) description;
      wantedBy = ["multi-user.target"];
      requiredBy = ["authentik.service"];
      before = ["authentik.service"];
      after = ["authentik-migrate.service"];
      requires = ["authentik-migrate.service"];
      serviceConfig =
        {
          Type = "oneshot";
          # Stays active after applying, so a changed trigger re-applies it on switch.
          RemainAfterExit = true;
          DynamicUser = true;
          User = "authentik";
          StateDirectory = "authentik";
          WorkingDirectory = "%S/authentik";
          EnvironmentFile = [config.age.secrets.authentik-env.path] ++ blueprint.environmentFiles;
          Environment = ["AUTHENTIK_CONFIG=/etc/authentik/config.yml"];
          ExecStartPre = blueprint.preStart ++ ["${pkgs.coreutils}/bin/install -D -m 0600 ${blueprint.file} %S/authentik/blueprints/${blueprint.fileName}"];
          ExecStart = "${manage} apply_blueprint ${blueprint.fileName}";
        }
        // lib.optionalAttrs (blueprint.condition != null) {ExecCondition = blueprint.condition;}
        // lib.optionalAttrs (blueprint.postStart != null) {ExecStartPost = blueprint.postStart;};
      restartTriggers = [config.age.secrets.authentik-env.file blueprint.file] ++ blueprint.restartTriggers;
    };
  in {
    options.forge.authentik.manage = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.services.authentik.authentikComponents.manage}/bin/manage.py";
      description = "Authentik's manage.py, for blueprint commands.";
    };
    options.forge.authentik.blueprints = mkOption {
      default = {};
      description = "Authentik blueprints, each applied by authentik-<name>-blueprint before Authentik starts, with authentik-env loaded.";
      type = types.attrsOf (types.submodule ({
        name,
        config,
        ...
      }: {
        options = {
          description = mkOption {
            type = types.str;
            description = "Unit description.";
          };
          file = mkOption {
            type = types.path;
            description = "Blueprint YAML to install and apply.";
          };
          fileName = mkOption {
            type = types.str;
            default = "${name}.yaml";
            description = "Name under the blueprints state directory.";
          };
          environmentFiles = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Environment files beyond authentik-env.";
          };
          restartTriggers = mkOption {
            type = types.listOf types.unspecified;
            default = [];
            description = "Triggers beyond authentik-env and the blueprint itself, typically its other secrets.";
          };
          preStart = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Commands run before the blueprint is installed.";
          };
          embeddedOutpostProvider = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Proxy provider to attach to the embedded outpost after applying.";
          };
          postStart = mkOption {
            type = types.nullOr types.str;
            default =
              if config.embeddedOutpostProvider == null
              then null
              else attachToEmbeddedOutpost config.embeddedOutpostProvider;
            defaultText = lib.literalMD "attaches `embeddedOutpostProvider` when set";
            description = "Command run after applying.";
          };
          condition = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "ExecCondition; the blueprint is skipped while it fails.";
          };
        };
      }));
    };

    config.systemd.services = lib.mapAttrs' (name: blueprint: lib.nameValuePair "authentik-${name}-blueprint" (unit blueprint)) config.forge.authentik.blueprints;
  };
}
