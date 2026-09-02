{config, ...}: let
  domain = "git.bylisa.dev";
  httpPort = 3000;
  sshPort = 2222;
  mailAddress = "forgejo@scheers.tech";
  mailSecret = ../../agenix/secrets/atlas/forgejo-mailer-password.age;
in {
  age.secrets.forgejo-mailer-password = {
    file = mailSecret;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    secrets.mailer.PASSWD = config.age.secrets.forgejo-mailer-password.path;

    dump = {
      enable = true;
      interval = "*-*-* 03:15:00";
      type = "tar.zst";
      age = "4w";
    };

    settings = {
      DEFAULT.APP_NAME = "Forgejo";

      server = {
        PROTOCOL = "http";
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = httpPort;

        DISABLE_SSH = false;
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_USER = "git";
        SSH_DOMAIN = domain;
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = sshPort;
        SSH_PORT = sshPort;
      };

      session = {
        COOKIE_SECURE = true;
        PROVIDER = "db";
      };

      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_NOTIFY_MAIL = true;
      };

      security = {
        MIN_PASSWORD_LENGTH = 14;
        GLOBAL_TWO_FACTOR_REQUIREMENT = "admin";
        REVERSE_PROXY_LIMIT = 1;
        REVERSE_PROXY_TRUSTED_PROXIES = "127.0.0.1/32";
      };

      webhook.ALLOWED_HOST_LIST = "external";
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtp+starttls";
        SMTP_ADDR = "m.scheers.tech";
        SMTP_PORT = 587;
        USER = mailAddress;
        FROM = "Forgejo <${mailAddress}>";
        ENVELOPE_FROM = mailAddress;
        ENABLE_HELO = true;
        HELO_HOSTNAME = domain;
        FORCE_TRUST_SERVER_CERT = false;
      };
      actions.ENABLED = false;
      metrics.ENABLED = true;
      repository.DEFAULT_BRANCH = "main";
      log = {
        LEVEL = "Info";
        MODE = "console";
      };
    };
  };

  environment.systemPackages = [config.services.forgejo.package];

  systemd.services.forgejo.restartTriggers = [mailSecret];

  services.postgresqlBackup = {
    enable = true;
    databases = ["forgejo"];
    compression = "zstd";
    startAt = "*-*-* 03:00:00";
  };

  networking.firewall.allowedTCPPorts = [sshPort];

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      merge_slashes off;
      client_max_body_size 512M;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString httpPort}";
      proxyWebsockets = true;
      extraConfig = "proxy_request_buffering off;";
    };

    locations."= /metrics".extraConfig = "return 404;";
  };
}
