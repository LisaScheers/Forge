let
  # https://emudhra.we-have-a-problem.com/ — compromised intermediates can
  # chain through either of these roots, including Sectigo cross-signs.
  pki.security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
  filterApple = pkgs:
    pkgs.callPackage ../../packages/certificate-trust/filter-apple-ca-roots.pkg.nix {};
  compatibleBuilder = pkgs:
    pkgs.buildcatrust.overridePythonAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace buildcatrust/cli.py --replace-fail \
            'unseen_blocklist = blocklist - saw_blocklist' \
            'unseen_blocklist = blocklist - saw_blocklist - {"emSign ECC Root CA - G3", "emSign Root CA - C1", "emSign ECC Root CA - C3"}'
        '';
    });
in {
  # The pinned Darwin PKI module still lists these NSS 3.131.1 removals.
  # Patch only blacklisted bundles so the default cacert and its dependents
  # keep their existing derivations. Other unknown names still fail.
  overlays.certificate-trust = _final: prev: {
    cacert = prev.lib.makeOverridable (args:
      prev.cacert.override (args
        // prev.lib.optionalAttrs ((args.blacklist or []) != [] && !(args ? buildcatrust)) {
          buildcatrust = compatibleBuilder prev;
        })) {};
  };
  nixos.base = pki;
  darwin.base = {
    lib,
    pkgs,
    ...
  }: {
    imports = [pki];
    security.pki.installCACerts = true;
    # Apple's command-line clients use this static file independently of
    # the OS intermediate blocklist and nix-darwin's Mozilla CA bundle.
    system.activationScripts.postActivation.text = ''
      ${filterApple pkgs}/bin/filter-apple-ca-roots /etc/ssl/cert.pem
    '';
    # Built-in pip has its own CA bundle. Honor explicit user overrides.
    environment.variables.PIP_CERT = lib.mkDefault "/etc/ssl/certs/ca-certificates.crt";
    launchd.user.envVariables.PIP_CERT = lib.mkDefault "/etc/ssl/certs/ca-certificates.crt";
  };
  perSystem = {pkgs, ...}: let
    filter = filterApple pkgs;
  in {
    packages.filter-apple-ca-roots = filter;
    checks.certificate-trust =
      pkgs.runCommand "certificate-trust-check" {
        nativeBuildInputs = [pkgs.python3 (compatibleBuilder pkgs) filter];
        NSS_CERTDATA = pkgs.cacert.src;
      } ''
        python3 -B ${../../tests/test_certificate_trust.py}
        touch "$out"
      '';
  };
}
