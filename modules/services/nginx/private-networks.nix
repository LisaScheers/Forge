{
  # Nginx access rules for vhosts that only the home LANs, their IPv6 prefixes
  # and the tailnet may reach. Prepend to a vhost's extraConfig.
  flake.lib.nginxPrivateNetworks = ''
    allow 127.0.0.1;
    allow ::1;
    allow 192.168.50.0/24;
    allow 192.168.111.0/24;
    allow 2a02:1810:515:c680::/64;
    allow 2a02:1810:515:c682::/64;
    allow 100.64.0.0/10;
    allow fd7a:115c:a1e0::/48;
    deny all;
  '';
}
