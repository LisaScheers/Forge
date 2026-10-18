{inputs, ...}: {
  darwin.base = {
    config,
    pkgs,
    lib,
    ...
  }: let
    nom = inputs.nix-output-monitor.packages.${pkgs.system}.default;
  in {
    system.tools.darwin-rebuild.enable = false;
    environment.systemPackages = [
      (config.system.build.darwin-rebuild.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            # Patch only builds: preserve stdout for jq and the activation path in $0.
            substituteInPlace "$out/bin/darwin-rebuild" \
              --replace-fail 'systemConfig="$(nix-build ' 'systemConfig="$(${lib.getExe' nom "nom-build"} ' \
              --replace-fail 'systemConfig=$(nix "''${flakeFlags[@]}" build ' 'systemConfig=$(${lib.getExe' nom "nom"} build "''${flakeFlags[@]}" '
          '';
      }))
    ];
  };
  home."lisa" = {
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
    nom-exe = lib.getExe' inputs.nix-output-monitor.packages.${pkgs.system}.default "nom";
    nom-build-exe = lib.getExe' inputs.nix-output-monitor.packages.${pkgs.system}.default "nom-build";
    nom-shell-exe = lib.getExe' inputs.nix-output-monitor.packages.${pkgs.system}.default "nom-shell";

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
              build|shell|develop|flake)
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
      (lib.meta.hiPrio nom-nix-wrappers)
    ];
  };
  flake-file.inputs = {
    nix-output-monitor.url = "github:maralorn/nix-output-monitor";
  };
}
