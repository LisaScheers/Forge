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
    ./home-assistant.nix
    ./dns.nix
    ./gotify.nix
    ./i2p.nix
    ./media.nix
    ./monitoring.nix
    ./neo4j.nix
    ./siem.nix
    ./onepassword-connect.nix
    ./acme.nix
  ];

  system.stateVersion = "25.11";
}
