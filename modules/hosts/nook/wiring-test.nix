{
  config,
  lib,
  withSystem,
  ...
}: let
  nook = config.flake.nixosConfigurations.nook.config;
  gateway = config.flake.lib.aiGatewayUrl;
  certs = nook.security.acme.certs;
  dyndns = nook.services.cloudflare-dyndns;
  certNames = cert: [cert.domain] ++ cert.extraDomainNames;
  # A virtual host serves its serverName (or its attribute name) and aliases,
  # with the certificate it names or, with enableACME, one of its own.
  vhosts = lib.filterAttrs (_: vhost: vhost.certificate != null) (lib.mapAttrs (name: vhost: rec {
      serverName =
        if vhost.serverName != null
        then vhost.serverName
        else name;
      names = [serverName] ++ vhost.serverAliases;
      certificate =
        if vhost.useACMEHost != null
        then vhost.useACMEHost
        else if vhost.enableACME
        then serverName
        else null;
    })
    nook.services.nginx.virtualHosts);

  # Each piece below is declared by a different feature module; these are the
  # links between them that evaluation alone would not catch.
  missingCertificates = lib.attrNames (lib.filterAttrs (_: vhost: !(certs ? ${vhost.certificate})) vhosts);
  namesOffCertificate = lib.concatLists (lib.mapAttrsToList (_: vhost:
    lib.optionals (certs ? ${vhost.certificate}) (lib.subtractLists (certNames certs.${vhost.certificate}) vhost.names))
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
