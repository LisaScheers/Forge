{...}: {
  imports = [
    ./nix.nix
    ./launchd.nix
    ./networking.nix
    ./packages.nix
  ];
  system.stateVersion = 7;
  documentation.doc.enable = false;
  services.openssh = {
    enable = true;
    extraConfig = ''
      KbdInteractiveAuthentication no
      PasswordAuthentication no
      PermitRootLogin no
    '';
  };
  users.users.lisa.openssh.authorizedKeys.keyFiles = [
    (../../homes + "/_lisa@vega/ssh/public-keys/home-server.pub")
  ];
  programs.ssh.knownHosts.vega-local = {
    hostNames = ["localhost"];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAxcMSI/fLy0nITZIQcsu3KQJhi3EFAsRpTGI/yPLox3";
  };
  security.pam.services.sudo_local.touchIdAuth = true;
  system.tools.darwin-uninstaller.enable = true;
  system.primaryUser = "lisa";
}
