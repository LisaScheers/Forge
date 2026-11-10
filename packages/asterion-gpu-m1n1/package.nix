{
  m1n1,
  fetchFromGitHub,
  buildPackages,
}: let
  revision = "7f6df96591b72c6ac9009cfa7e991dc5eafc7def";
  source = fetchFromGitHub {
    owner = "omacom";
    repo = "m1n1";
    rev = revision;
    hash = "sha256-CQ/cbSUvM2pUYUiq1SexzY4LuAPXdscshLihDSwh0To=";
  };
in
  (m1n1.override {customLogo = null;}).overrideAttrs (old: {
    pname = "asterion-gpu-m1n1";
    version = "unstable-2026-11-07";
    M1N1_VERSION_TAG = "asterion-gpu-${builtins.substring 0 12 revision}";
    src = source;
    cargoDeps = m1n1.rustPlatform.fetchCargoVendor {
      pname = "asterion-gpu-m1n1";
      version = "unstable-2026-11-07";
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
          -c commit.gpgsign=false commit -qm 'Pinned source validation fixture'
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
        description = "Pinned Asterion m1n1 bootloader and matching proxy sources";
        changelog = "https://github.com/omacom/m1n1/commit/${revision}";
      };
  })
