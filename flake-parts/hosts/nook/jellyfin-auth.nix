{
  forge.modules.nixos.nook = {
    config,
    lib,
    pkgs,
    ...
  }: let
    source = ../../../services/jellyfin-auth;
    secret = ../../agenix/secrets/shared/jellyfin-ldap-env.age;
    plugin = pkgs.fetchzip {
      url = "https://repo.jellyfin.org/files/plugin/ldap-authentication/ldap-authentication_24.0.0.0.zip";
      hash = "sha256-yiyoLahv+tzNWB4JVPoC4fxl+gj8IoYVXv0bi2FGlmM=";
      stripRoot = false;
    };
    dataDir = config.services.jellyfin.dataDir;
  in {
    age.secrets.jellyfin-ldap-env.file = secret;

    systemd.services.jellyfin = {
      restartTriggers = [plugin secret source];
      serviceConfig.LoadCredential = ["jellyfin-ldap-env:${config.age.secrets.jellyfin-ldap-env.path}"];
      preStart = lib.mkAfter ''
        install -d -m 0700 ${lib.escapeShellArg "${dataDir}/plugins/LDAP Authentication_24.0.0.0"}
        cp -f ${plugin}/* ${lib.escapeShellArg "${dataDir}/plugins/LDAP Authentication_24.0.0.0/"}
        chmod u+w ${lib.escapeShellArg "${dataDir}/plugins/LDAP Authentication_24.0.0.0/meta.json"}
        ${pkgs.python3}/bin/python3 ${source}/configure.py ${lib.escapeShellArg "${dataDir}/plugins/configurations/LDAP-Auth.xml"}
      '';
    };

    systemd.services.jellyfin-auth-link = {
      description = "Link existing Jellyfin accounts to Authentik LDAP";
      wantedBy = ["multi-user.target"];
      after = ["jellyfin.service"];
      requires = ["jellyfin.service"];
      partOf = ["jellyfin.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${source}/link.py ${dataDir}/data/jellyfin.db";
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
      restartTriggers = [source secret];
    };
  };
}
