{
  nixos.asterion.networking.networkmanager.ensureProfiles.profiles.lisa-ent = {
    connection = {
      id = "Lisa Ent";
      uuid = "e7b19a8d-888a-4de6-957f-2be1d481be5d";
      type = "wifi";
      autoconnect = true;
      autoconnect-priority = 100;
    };
    wifi = {
      mode = "infrastructure";
      ssid = "Lisa Ent";
    };
    wifi-security = {
      key-mgmt = "wpa-eap";
      pmf = 3;
    };
    "802-1x" = {
      eap = "peap;";
      identity = "uid-lisa@scheers.tech";
      phase2-auth = "mschapv2";
      # Public CA exported from Vega's existing Lisa Ent trust configuration.
      ca-cert = "${./unifi-radius-ca.pem}";
      domain-match = "standard.ui.com";
      # The desktop secret agent enrolls the password in Lisa's keyring.
      password-flags = 1;
    };
    ipv4.method = "auto";
    ipv6 = {
      method = "auto";
      addr-gen-mode = "stable-privacy";
    };
  };
}
