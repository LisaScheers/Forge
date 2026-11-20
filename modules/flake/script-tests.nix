{lib, ...}: let
  # tests/ exercises repository scripts by path, so keep their relative layout.
  sources = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../tests
      ../../scripts
      ../../.github/scripts
      ../../Justfile
      ../../.envrc
      ../../modules/shell/git-credential-fj.sh
      ../../services/jellyfin-auth
    ];
  };
in {
  perSystem = {pkgs, ...}: {
    checks.script-tests =
      pkgs.runCommand "script-tests" {
        nativeBuildInputs = with pkgs; [bash coreutils direnv git gnugrep gnused jq just nix python3];
      } ''
        cp -r ${sources} source
        chmod -R u+w source
        cd source
        # The Linux sandbox has no /usr/bin/env for Justfile recipe shebangs or
        # the mock commands the tests write.
        sed -i "s|#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|" tests/*.py Justfile
        patchShebangs --build .
        export HOME="$TMPDIR" NIX_STATE_DIR="$TMPDIR/nix"
        python3 -B -m unittest discover -s tests -v
        touch "$out"
      '';
  };
}
