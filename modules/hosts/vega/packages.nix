{
  # OrbStack 2.2.5 includes the Linux kernel fix for CVE-2026-98432.
  overlays.orbstack = final: prev: {
    orbstack =
      if prev.lib.versionAtLeast prev.orbstack.version "2.2.5"
      then prev.orbstack
      else
        prev.orbstack.overrideAttrs {
          version = "2.2.5-21124";
          src = final.fetchurl {
            url = "https://cdn-updates.orbstack.dev/arm64/OrbStack_v2.2.5_21124_arm64.dmg";
            hash = "sha256-8riH0moh4KEhR+sAUpd4J5Syb0Yfd8a5zftX9XatXm0=";
          };
        };
  };

  darwin.vega = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      just
      sops
      age
      ssh-to-age
      alejandra
      fh
      nil
      nixd
      ripgrep
      raycast
      ghostty-bin
      ghostty-bin.terminfo
      element-desktop
      #mpv
      obsidian
      orbstack
      slack
      the-unarchiver
      oxfmt
      oxlint
    ];
  };
}
