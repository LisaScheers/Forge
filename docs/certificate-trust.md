# eMudhra certificate trust mitigation

Source: [eMudhra incident and platform guidance](https://emudhra.we-have-a-problem.com/),
checked 2026-10-24. The compromised intermediates also have Sectigo cross-signs.

`modules/security/certificate-trust.nix` adds these exclusions to every Forge
NixOS and nix-darwin base profile:

```nix
security.pki.caCertificateBlacklist = [
  "Comodo AAA Services root"
  "emSign ECC Root CA - G3"
];
```

The pinned nix-darwin already includes the exclusions internally. Keeping them
explicit records the incident policy across both platforms and future pins.
Darwin explicitly enables `security.pki.installCACerts` so nix-darwin manages
and installs the filtered Mozilla bundle.
The pinned Darwin module also blacklists three roots already absent from NSS
3.131.1. A small `buildcatrust` compatibility patch allows only those known
absent names. Other unknown blacklist names still fail. This patch applies only
to blacklisted bundles; the default package CA bundle and its dependents keep
their existing derivations.
Custom `security.pki.certificates` / `certificateFiles` remain unchanged; these
options must not reintroduce the compromised roots.

## macOS command-line clients

Apple's intermediate blocklist does not protect command-line clients using the
static `/etc/ssl/cert.pem` bundle. During Darwin activation, Forge filters only
the two affected certificate blocks from this file, preserving the remaining
Apple roots, owner and permissions. It saves the original once as
`/etc/ssl/cert.pem.before-emudhra`, then atomically replaces the bundle. Repeated
activation leaves already-filtered content and the original backup unchanged.
A symlink or removal of every certificate causes a refusal rather than an
overwrite. The same filter runs on later activations if an OS update restores
the affected roots.

Pip uses its standard `PIP_CERT` environment variable to select the Nix-managed
`/etc/ssl/certs/ca-certificates.crt` bundle, including in new launchd user
processes. Explicit user configuration still takes precedence. No Apple Python
installation or application bundle is edited. Existing processes retain their
environment until restarted.

Other applications that embed independent trust stores or runtimes still need
their upstream updates. This mitigation does not add Certificate Transparency
enforcement or general revocation checking.

## Verification and activation

```sh
nix build .#checks.aarch64-darwin.certificate-trust
```

The check exercises scoped removal, unaffected roots, repeat runs, backup and
permission preservation, and refusal of symlink/empty-result inputs.
It also checks that known removed roots do not break the Nix bundle builder
and that an unknown blacklist name still fails.
Live verification on 2026-10-24 used an isolated copy of Apple's bundle and the
generated Vega bundle with unmodified `/usr/bin/curl`. All four incident
endpoints failed with curl exit 60 (issuer missing or certificate rejected),
while `https://example.com/` returned HTTP 200 with both bundles. The Apple
copy retained 126 of 128 roots; the live file was unchanged. All four host
configurations evaluate with the two exclusions, and Vega evaluates with
`installCACerts = true`.

No host configuration has been activated. The upki/OpenSSL experiment was
removed when Lisa chose this mitigation instead: upki 1.0.1 checks leaf
revocation and did not cover these compromised intermediate chains.
