{
  m1n1,
  fetchFromGitHub,
  buildPackages,
}: let
  revision = "f5a82fdb6264edd2fb0c02e2d0f750bf33380854";
  source = fetchFromGitHub {
    owner = "omacom";
    repo = "m1n1";
    rev = revision;
    hash = "sha256-8Fjw+2MGkqdGEOWOBuV2yXG0wDOAuaebD+tInJL/Be8=";
  };
in
  (m1n1.override {customLogo = null;}).overrideAttrs (old: {
    pname = "asterion-gpu-test-m1n1";
    version = "unstable-2026-10-24";
    M1N1_VERSION_TAG = "asterion-gpu-test-${builtins.substring 0 12 revision}";
    src = source;
    cargoDeps = m1n1.rustPlatform.fetchCargoVendor {
      pname = "asterion-gpu-test-m1n1";
      version = "unstable-2026-10-24";
      src = "${source}/rust";
      sourceRoot = "rust";
      hash = "sha256-Rw9xhDAZx1YIiS62fKmSoq8FDZ1JJNhA7p/Wx35R7RQ=";
    };
    nativeCheckInputs =
      (old.nativeCheckInputs or [])
      ++ [
        buildPackages.git
        buildPackages.llvmPackages.clang
      ];
    preCheck =
      (old.preCheck or "")
      + ''
        # Host fixtures use both clang and cc. Keep Nix's production hardening
        # flags out of their deliberately synthetic C programs.
        mkdir check-bin
        ln -s ${buildPackages.llvmPackages.clang}/bin/clang check-bin/cc
        export PATH="$PWD/check-bin:$PATH"
        export NIX_HARDENING_ENABLE=
        git init -q
        git add .
        git -c user.name=Builder -c user.email=builder@example.invalid \
          -c commit.gpgsign=false commit -qm 'Pinned source test fixture'
      '';
    passthru =
      (old.passthru or {})
      // {
        sourceRevision = revision;
        # This exposes the matching proxy client without installing anything on the Mac.
        proxySource = "${source}/proxyclient";
      };
    meta =
      old.meta
      // {
        description = "Pinned RAM-only Asterion GPU-test m1n1 and matching proxy sources";
        changelog = "https://github.com/omacom/m1n1/commit/${revision}";
      };
  })
