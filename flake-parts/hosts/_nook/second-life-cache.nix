{
  lib,
  pkgs,
  ...
}: let
  listenAddress = "192.168.111.2";
  listenPort = 3128;
  socksPort = 1080;
  cacheRoot = "/srv/disks/second-life-cache/squid-cache";
  cacheSizeMb = 190000;
  storeIdHelper = pkgs.writeTextFile {
    name = "second-life-squid-store-id";
    executable = true;
    text = ''
      #!${pkgs.perl}/bin/perl
      use strict;
      use warnings;

      $| = 1;

      while (my $line = <STDIN>) {
        chomp $line;

        my @fields = split /\s+/, $line;
        my $prefix = "";
        my $url = shift @fields // "";

        if (@fields && $url =~ /^\d+$/) {
          $prefix = "$url ";
          $url = shift @fields // "";
        }

        if ($url =~ m{^https?://sim[^/]*\.agni\.lindenlab\.com[^?]*/cap/[^?]*/\?texture_id=([^&\s]+)}i) {
          print $prefix . qq(OK store-id="http://agni.lindenlab.com/texture/$1"\n);
          next;
        }

        if ($url =~ m{^https?://sim[^/]*\.agni\.lindenlab\.com[^?]*/cap/[^?]*/\?mesh_id=([^&\s]+)}i) {
          print $prefix . qq(OK store-id="http://agni.lindenlab.com/mesh/$1"\n);
          next;
        }

        if ($url =~ m{^https?://asset-cdn\.agni\.lindenlab\.com[^?]*\?texture_id=([^&\s]+)}i) {
          print $prefix . qq(OK store-id="http://agni.lindenlab.com/texture/$1"\n);
          next;
        }

        if ($url =~ m{^https?://asset-cdn\.agni\.lindenlab\.com[^?]*\?mesh_id=([^&\s]+)}i) {
          print $prefix . qq(OK store-id="http://agni.lindenlab.com/mesh/$1"\n);
          next;
        }

        print $prefix . "ERR\n";
      }
    '';
  };
in {
  networking.firewall = {
    allowedTCPPorts = [
      listenPort
      socksPort
    ];
    allowedUDPPorts = [socksPort];
  };

  services.dante = {
    enable = true;
    config = ''
      internal: ${listenAddress} port = ${toString socksPort}
      external: enp7s0

      clientmethod: none
      socksmethod: none

      client pass {
        from: 192.168.50.0/24 to: 0.0.0.0/0
        log: connect disconnect error
      }

      client pass {
        from: 192.168.111.0/24 to: 0.0.0.0/0
        log: connect disconnect error
      }

      socks pass {
        from: 192.168.50.0/24 to: 0.0.0.0/0
        command: connect udpassociate
        log: connect disconnect error
      }

      socks pass {
        from: 192.168.111.0/24 to: 0.0.0.0/0
        command: connect udpassociate
        log: connect disconnect error
      }

      socks pass {
        from: 0.0.0.0/0 to: 192.168.50.0/24
        command: udpreply
        log: connect disconnect error
      }

      socks pass {
        from: 0.0.0.0/0 to: 192.168.111.0/24
        command: udpreply
        log: connect disconnect error
      }
    '';
  };

  services.squid = {
    enable = true;
    proxyAddress = listenAddress;
    proxyPort = listenPort;
    configText = ''
      acl localnet src 192.168.50.0/24
      acl localnet src 192.168.111.0/24
      acl localnet src 2a02:1810:515:c682::/64
      acl localnet src 2a02:1810:515:c680::/64
      acl localnet src 100.64.0.0/10
      acl localnet src fd7a:115c:a1e0::/48
      acl proxy_host src ${listenAddress}

      acl SSL_ports port 443
      acl SSL_ports port 12043
      acl Safe_ports port 80
      acl Safe_ports port 21
      acl Safe_ports port 443
      acl Safe_ports port 12043
      acl Safe_ports port 70
      acl Safe_ports port 210
      acl Safe_ports port 1025-65535
      acl Safe_ports port 280
      acl Safe_ports port 488
      acl Safe_ports port 591
      acl Safe_ports port 777
      acl CONNECT method CONNECT

      http_access deny !Safe_ports
      http_access deny CONNECT !SSL_ports
      http_access allow localhost manager
      http_access allow proxy_host manager
      http_access deny manager
      http_access deny to_localhost
      http_access allow localnet
      http_access allow localhost
      http_access deny all

      http_port ${listenAddress}:${toString listenPort}
      pid_filename /run/squid.pid
      cache_effective_user squid squid

      cache_log stdio:/var/log/squid/cache.log
      access_log stdio:/var/log/squid/access.log
      cache_store_log stdio:/var/log/squid/store.log

      cache_dir ufs ${cacheRoot} ${toString cacheSizeMb} 32 256
      cache_mem 512 MB
      maximum_object_size 1024 MB
      range_offset_limit -1
      visible_hostname home-server-second-life-cache
      coredump_dir ${cacheRoot}

      store_id_program ${storeIdHelper}
      store_id_children 32 startup=4 idle=4 concurrency=0
      acl second_life_asset_hosts dstdomain .agni.lindenlab.com asset-cdn.agni.lindenlab.com
      store_id_access allow second_life_asset_hosts
      store_id_access deny all

      forwarded_for delete

      acl bakeserver dstdomain bake-texture.agni.lindenlab.com
      cache deny bakeserver

      refresh_pattern ^http://agni\.lindenlab\.com/(texture|mesh)/ 259200 20% 302400 override-expire
      refresh_pattern /cap/ 259200 20% 302400 override-expire
      refresh_pattern asset-cdn\.agni\.lindenlab\.com/.* 259200 20% 302400 override-expire
      refresh_pattern ^ftp: 1440 20% 10080
      refresh_pattern ^gopher: 1440 0% 1440
      refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
      refresh_pattern . 0 20% 4320
    '';
  };

  systemd.services.squid = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    preStart = lib.mkBefore ''
      install -d -m 0750 -o squid -g squid ${cacheRoot}
    '';
    unitConfig.RequiresMountsFor = cacheRoot;
  };

  systemd.tmpfiles.rules = [
    "d ${cacheRoot} 0750 squid squid - -"
  ];
}
