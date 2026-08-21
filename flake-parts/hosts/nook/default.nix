{
  imports = [
    ./_hardware-configuration.nix
    ./networking.nix
    ./boot.nix
    ./nix.nix
    ./users.nix
    ./sudo.nix
    ./ssh.nix
    ./packages.nix
    ./disk.nix
    ./second-life-cache.nix
    ./firestorm-streaming.nix
    ./home-assistant.nix
    ./dns.nix
    ./gotify.nix
    ./media.nix
    ./monitoring.nix
    ./acme.nix
  ];

  services.fwupd.enable = true;
  system.stateVersion = "25.11";
}
