{
  lib,
  pkgs,
  ...
}: let
  primaryDomain = "ha.bylisa.dev";
  localDomain = "ha.local.bylisa.dev";
  proxyErrorPage = import ./_nginx-error-page.nix {inherit pkgs;};
in {
  services.home-assistant = {
    enable = true;
    package = pkgs.home-assistant;
    configDir = "/var/lib/hass";
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"
    ];

    config = {
      default_config = {};
      homeassistant = {
        name = "Home Assistant";
        #51.203108, 4.769569
        latitude = "51.203108";
        longitude = "4.769569";
        unit_system = "metric";
        time_zone = "Europe/Brussels";
        temperature_unit = "C";
        external_url = "https://${primaryDomain}";
        internal_url = "https://${localDomain}";
      };
      http = {
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };
    };
    customComponents = with pkgs.home-assistant-custom-components; [
      volkswagencarnet
    ];
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.enableRedistributableFirmware = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="8087", ATTR{idProduct}=="0029", SYMLINK+="home-assistant/intel-bluetooth"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2357", ATTR{idProduct}=="0604", ATTR{serial}=="E848B8C82000", SYMLINK+="home-assistant/tp-link-ub500"
  '';

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${primaryDomain} = lib.mkMerge [
      proxyErrorPage
      {
        serverAliases = [localDomain];
        forceSSL = true;
        useACMEHost = primaryDomain;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8123";
          proxyWebsockets = true;
        };
      }
    ];
  };
}
