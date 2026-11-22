{
  nixos.nook = {
    lib,
    pkgs,
    ...
  }: {
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      devices = ["/dev/disk/by-id/nvme-eui.002538ba71b63d8a"];
    };

    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "lisa" "nix-remote-builder"];
    };

    environment.systemPackages = with pkgs;
      map lib.lowPrio [
        git
        nano
        ripgrep
      ];

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    services.fwupd.enable = true;
    system.stateVersion = "26.11";
  };
}
