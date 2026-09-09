{inputs, ...}: {
  forge.modules.homeManager."lisa" = {
    pkgs,
    config,
    ...
  }: {
    programs.nushell = {
      enable = true;
      plugins = with pkgs.nushellPlugins; [
        polars
        formats
        gstat
        query
        #semver
      ];
      settings.show_banner = false;
      extraEnv = ''
        $env.PATH = ([
          "/etc/profiles/per-user/${config.home.username}/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
        ] | append $env.PATH | uniq)

        alias codex-yolo = codex --yolo
      '';
    };
  };
  forge.overlays.nushell = _final: prev: {
    # Nushell's tests assume a TTY and fail with EPERM/wrong SHLVL on Darwin builders.
    nushell =
      if prev.stdenv.hostPlatform.isDarwin
      then
        prev.nushell.overrideAttrs (_old: {
          doCheck = false;
        })
      else prev.nushell;
  };
}
