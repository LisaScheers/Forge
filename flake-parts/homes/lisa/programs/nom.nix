{
  pkgs,
  lib,
  osConfig ? null,
  ...
}: let
  nix-package =
    if osConfig != null
    then osConfig.nix.package
    else pkgs.nix;
  nix-exe = lib.getExe nix-package;
  nom-exe = lib.getExe' pkgs.nix-output-monitor "nom";
  nom-build-exe = lib.getExe' pkgs.nix-output-monitor "nom-build";
  nom-shell-exe = lib.getExe' pkgs.nix-output-monitor "nom-shell";

  nom-nix-wrappers = pkgs.symlinkJoin {
    name = "nom-nix-wrappers";
    paths = [
      (pkgs.writeShellApplication {
        name = "nix";
        runtimeInputs = [nix-package];
        text = ''
          if [ "$#" -eq 0 ]; then
            exec ${nix-exe}
          fi

          case "$1" in
            build|shell|develop)
              exec ${nom-exe} "$@"
              ;;
            *)
              exec ${nix-exe} "$@"
              ;;
          esac
        '';
      })
      (pkgs.writeShellApplication {
        name = "nix-build";
        runtimeInputs = [nix-package];
        text = ''
          exec ${nom-build-exe} "$@"
        '';
      })
      (pkgs.writeShellApplication {
        name = "nix-shell";
        runtimeInputs = [nix-package];
        text = ''
          exec ${nom-shell-exe} "$@"
        '';
      })
    ];
  };
in {
  home.packages = [
    pkgs.nix-output-monitor
    nom-nix-wrappers
  ];
}
