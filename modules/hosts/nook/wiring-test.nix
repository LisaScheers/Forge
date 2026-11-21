{
  config,
  lib,
  withSystem,
  ...
}: let
  nook = config.flake.nixosConfigurations.nook.config;
  gateway = config.flake.lib.aiGatewayUrl;
  vhosts = nook.services.nginx.virtualHosts;
  certs = nook.security.acme.certs;
  # Each piece below is declared by a different feature module; these are the
  # links between them that evaluation alone would not catch.
  problems =
    map (name: "virtual host ${name} uses a certificate nothing requests") (lib.attrNames (lib.filterAttrs (_: vhost: vhost.useACMEHost != null && !(certs ? ${vhost.useACMEHost})) vhosts))
    ++ map (name: "${name} has a certificate but is missing from cloudflare-dyndns domains") (lib.filter (name: !(builtins.elem name nook.services.cloudflare-dyndns.domains)) (["ha.bylisa.dev"] ++ certs."ha.bylisa.dev".extraDomainNames))
    ++ lib.optional (vhosts."cliproxy.local.bylisa.dev".locations."/".proxyPass != gateway) "the gateway's nginx upstream is not flake.lib.aiGatewayUrl"
    ++ lib.optional (nook.virtualisation.oci-containers.containers.cognee.environment.LLM_ENDPOINT != "${gateway}/v1") "Cognee does not call flake.lib.aiGatewayUrl";
in {
  flake.checks.x86_64-linux.nook-wiring = withSystem "x86_64-linux" ({pkgs, ...}:
    assert lib.assertMsg (problems == []) "nook-wiring: ${lib.concatStringsSep "; " problems}";
      pkgs.runCommand "nook-wiring" {} ''
        touch "$out"
      '');
}
