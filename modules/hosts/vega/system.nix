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

    launchd.user.envVariables = {
      PATH = "/Users/lisa/.local/bin:/etc/profiles/per-user/lisa/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      SSH_AUTH_SOCK = "/Users/lisa/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };
    forge.hosts = {
      "2a02:1810:515:c682::1" = ["internal.bylisa.dev"];
      "192.168.50.1" = ["internal.bylisa.dev"];
    };
  };
}
