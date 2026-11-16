{
  codex,
  fetchFromGitHub,
  lib,
  stdenv,
}:
codex.overrideAttrs (old:
    {
      version = "0.169.0-alpha.11.1";
      buildCommit = "226fa88979b1a9d76dc36f339ee9c5fbdb2c8e7f";
      src = fetchFromGitHub {
        owner = "openai";
        repo = "codex";
        rev = "226fa88979b1a9d76dc36f339ee9c5fbdb2c8e7f";
        hash = "sha256-404imvx5dVwkZXyNqnLPdaKgDUG07d044R20BE3wgeY=";
      };
      patches = (old.patches or []) ++ [(builtins.toFile "codex-native-capture.patch" (builtins.readFile ./capture.patch))];
    }
    // lib.optionalAttrs stdenv.hostPlatform.isLinux {
      # Limit release-build memory pressure on Nook's 32 GiB host.
      preBuild =
        (old.preBuild or "")
        + ''
          if (( NIX_BUILD_CORES == 0 || NIX_BUILD_CORES > 2 )); then
            export NIX_BUILD_CORES=2
          fi
        '';
    })
