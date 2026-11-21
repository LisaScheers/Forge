{
  config,
  lib,
  withSystem,
  ...
}: let
  nook = config.flake.nixosConfigurations.nook.config;
  gateway = config.flake.lib.aiGatewayUrl;
  vhosts = lib.filterAttrs (_: vhost: vhost.useACMEHost != null) nook.services.nginx.virtualHosts;
  certs = nook.security.acme.certs;
  dyndns = nook.services.cloudflare-dyndns;
  certNames = cert: [cert.domain] ++ cert.extraDomainNames;

  # Each piece below is declared by a different feature module; these are the
  # links between them that evaluation alone would not catch.
  missingCertificates = lib.attrNames (lib.filterAttrs (_: vhost: !(certs ? ${vhost.useACMEHost})) vhosts);
  namesOffCertificate = lib.concatLists (lib.mapAttrsToList (name: vhost:
    lib.optionals (certs ? ${vhost.useACMEHost})
    (lib.subtractLists (certNames certs.${vhost.useACMEHost}) ([name] ++ vhost.serverAliases)))
  vhosts);
  publicNames = lib.filter (name: !(lib.hasSuffix ".local.bylisa.dev" name)) (lib.concatMap certNames (lib.attrValues certs));
  namesWithoutDyndns = lib.subtractLists dyndns.domains publicNames;

  problems =
    lib.optional (!dyndns.enable) "cloudflare-dyndns is disabled, so no public name follows Nook's address"
    ++ map (name: "virtual host ${name} uses a certificate nothing requests") missingCertificates
    ++ map (name: "${name} is served but missing from its virtual host's certificate") namesOffCertificate
    ++ map (name: "${name} has a public certificate but is missing from cloudflare-dyndns domains") namesWithoutDyndns
    ++ lib.optional (nook.services.nginx.virtualHosts."cliproxy.local.bylisa.dev".locations."/".proxyPass != gateway) "the gateway's nginx upstream is not flake.lib.aiGatewayUrl"
    ++ lib.optional (nook.virtualisation.oci-containers.containers.cognee.environment.LLM_ENDPOINT != "${gateway}/v1") "Cognee does not call flake.lib.aiGatewayUrl";
in {
  flake.checks.x86_64-linux.nook-wiring = withSystem "x86_64-linux" ({pkgs, ...}:
    assert lib.assertMsg (problems == []) "nook-wiring: ${lib.concatStringsSep "; " problems}";
      pkgs.runCommand "nook-wiring" {} ''
        touch "$out"
      '');
}
