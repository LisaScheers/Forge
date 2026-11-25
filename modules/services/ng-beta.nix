{
  # Demo of the N&G Pool Service website. services/ng-beta/site is a frozen
  # build of that project (`SITE_URL=https://beta.ng.bylisa.dev npm run build`);
  # replace the folder to release a newer demo.
  nixos.atlas = let
    domain = "beta.ng.bylisa.dev";
    site = builtins.path {
      path = ../../services/ng-beta/site;
      name = "ng-beta-site";
    };
  in {
    services.nginx.virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      root = site;
      # A location's own add_header would drop these, so none of them sets one.
      extraConfig = ''
        charset utf-8;
        add_header X-Robots-Tag "noindex, nofollow" always;
        add_header X-Content-Type-Options nosniff always;
        add_header Referrer-Policy strict-origin-when-cross-origin always;
        error_page 404 /404.html;
      '';
      locations = {
        "/".tryFiles = "$uri $uri/ =404";
        # The demo must not compete with the shop's real site in search results.
        "= /robots.txt".extraConfig = ''
          default_type "text/plain; charset=utf-8";
          return 200 "User-agent: *\nDisallow: /\n";
        '';
        "~ \\.md$".extraConfig = ''
          types {}
          default_type "text/markdown; charset=utf-8";
        '';
        "~ \\.jsonld$".extraConfig = ''
          types {}
          default_type "application/ld+json; charset=utf-8";
        '';
      };
    };
  };
}
