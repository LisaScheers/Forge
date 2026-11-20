{config, ...}: let
  hostKeys = config.secrets.pubkeys.hosts;
in {
  darwin.vega = {
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
      ../../security/ssh/public-keys/home-server.pub
    ];
    programs.ssh.knownHosts.vega-local = {
      hostNames = ["localhost"];
      publicKey = hostKeys.vega;
    };
    security.pam.services.sudo_local.touchIdAuth = true;
    system.tools.darwin-uninstaller.enable = true;
    system.primaryUser = "lisa";
  };
}
