{config, ...}: let
  nook = config.network.nook;
in {
  # Asterion reaches Cognee over Tailscale, also away from the home LAN.
  nixos.asterion.networking.hosts.${nook.tailscale} = ["cognee.local.bylisa.dev"];
}
