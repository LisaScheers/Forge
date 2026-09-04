let
  mediaVlanInterface = "enp7s0.200";
  mediaRoutingTable = 200;
  mediaRoutingMark = 200;
in {
  networking = {
    useDHCP = false;
    useNetworkd = true;
    firewall = {
      enable = true;
      checkReversePath = false;
      allowedTCPPorts = [22];
      allowedUDPPorts = [];
    };
  };

  systemd.network = {
    enable = true;
    config.routeTables.media-egress = mediaRoutingTable;
    netdevs."20-media-vlan" = {
      netdevConfig = {
        Name = mediaVlanInterface;
        Kind = "vlan";
      };
      vlanConfig.Id = 200;
    };
    networks = {
      "10-uplink" = {
        matchConfig.Name = "enp7s0";
        address = ["192.168.111.2/24"];
        gateway = ["192.168.111.1"];
        dns = ["192.168.111.1"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = true;
          LinkLocalAddressing = "ipv6";
          VLAN = [mediaVlanInterface];
        };
        ipv6AcceptRAConfig.UseDNS = true;
        linkConfig.RequiredForOnline = "routable";
      };
      "20-media-vlan" = {
        matchConfig.Name = mediaVlanInterface;
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
        dhcpV4Config = {
          RouteTable = mediaRoutingTable;
          RouteMetric = 200;
          UseDNS = false;
        };
        routingPolicyRules = [
          {
            FirewallMark = mediaRoutingMark;
            Table = mediaRoutingTable;
            Priority = 20000;
            Family = "both";
          }
        ];
        linkConfig.RequiredForOnline = "no";
      };
    };
  };

  time.timeZone = "Europe/Brussels";
}
