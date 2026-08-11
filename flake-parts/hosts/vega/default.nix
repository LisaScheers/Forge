{...}: {
  imports = [
    ./nix.nix
    ./launchd.nix
    ./networking.nix
    ./homebrew.nix
    ./comicCodeNerdFont.nix
    ./packages.nix
    ./homes.nix
  ];
  system.stateVersion = 7;
  documentation.doc.enable = false;
  security.pam.services.sudo_local.touchIdAuth = true;
  system.tools.darwin-uninstaller.enable = true;
  system.primaryUser = "lisa";
}
