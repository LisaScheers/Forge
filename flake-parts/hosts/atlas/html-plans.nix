{config, ...}: let
  hostName = "plans.bylisa.dev";
  appUpstream = "http://127.0.0.1:${toString config.services.html-plans.port}";
  authentikUpstream = "http://127.0.0.1:9000";

  authentikResponseHeaders = ''
    auth_request_set $auth_cookie $upstream_http_set_cookie;
    add_header Set-Cookie $auth_cookie always;

    auth_request_set $authentik_username $upstream_http_x_authentik_username;
    auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
    auth_request_set $authentik_entitlements $upstream_http_x_authentik_entitlements;
    auth_request_set $authentik_email $upstream_http_x_authentik_email;
    auth_request_set $authentik_name $upstream_http_x_authentik_name;
    auth_request_set $authentik_uid $upstream_http_x_authentik_uid;

    proxy_set_header X-Authentik-Username $authentik_username;
    proxy_set_header X-Authentik-Groups $authentik_groups;
    proxy_set_header X-Authentik-Entitlements $authentik_entitlements;
    proxy_set_header X-Authentik-Email $authentik_email;
    proxy_set_header X-Authentik-Name $authentik_name;
    proxy_set_header X-Authentik-Uid $authentik_uid;
  '';
in {
  services.html-plans = {
    enable = true;
    bindAddress = "127.0.0.1";
    port = 8787;
    publicBaseUrl = "https://${hostName}";
    trustAuthentikHeaders = true;
  };

  services.nginx.virtualHosts.${hostName} = {
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      proxy_buffers 8 16k;
      proxy_buffer_size 32k;
    '';

    locations = {
      "= /healthz" = {
        proxyPass = appUpstream;
      };

      "/outpost.goauthentik.io" = {
        proxyPass = "${authentikUpstream}/outpost.goauthentik.io";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };

      "/api/v1/" = {
        proxyPass = appUpstream;
        extraConfig = ''
          if ($http_authorization !~* "^Bearer +") { return 401; }
          auth_request /outpost.goauthentik.io/auth/nginx;
          ${authentikResponseHeaders}
          proxy_set_header Authorization "";
        '';
      };

      "/" = {
        proxyPass = appUpstream;
        extraConfig = ''
          auth_request /outpost.goauthentik.io/auth/nginx;
          error_page 401 = @goauthentik_proxy_signin;
          ${authentikResponseHeaders}
          proxy_set_header Authorization "";
        '';
      };

      "@goauthentik_proxy_signin" = {
        extraConfig = ''
          internal;
          add_header Set-Cookie $auth_cookie always;
          return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
        '';
      };
    };
  };
}
