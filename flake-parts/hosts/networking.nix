{
  flake.modules.nixos.networking = ./_nixos-networking.nix;
  flake.modules.darwin.networking = ./_darwin-tailscale.nix;
}
