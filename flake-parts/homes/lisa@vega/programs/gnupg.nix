{
  forge.modules.homeManager."lisa@vega" = {pkgs, ...}: {
    programs.gpg = {
      enable = true;
      scdaemonSettings = {
        # Share macOS's smartcard service with other YubiKey applications.
        disable-ccid = true;
        pcsc-shared = true;
      };
    };

    services.gpg-agent = {
      enable = true;
      enableScDaemon = true;
      # SSH and Git signing continue to use 1Password.
      enableSshSupport = false;
      pinentry.package = pkgs.pinentry_mac;
    };

    home.packages = [pkgs.yubikey-manager];
  };
}
