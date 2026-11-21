{
  config,
  lib,
  withSystem,
  ...
}: let
  nook = config.flake.nixosConfigurations.nook.config;
  gateway = config.flake.lib.aiGatewayUrl;

  # The certificate and DynDNS rules, over plain data shaped like the NixOS
  # options, so the fixtures below run the same code. Each entry lists the
  # offending names.
  problemsIn = {
    virtualHosts,
    certs,
    dyndns,
  }: let
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
      virtualHosts);
    publicNames = lib.filter (name: !(lib.hasSuffix ".local.bylisa.dev" name)) (lib.concatMap certNames (lib.attrValues certs));
  in {
    "cloudflare-dyndns is disabled" = lib.optional (!dyndns.enable) "cloudflare-dyndns";
    "virtual hosts whose certificate nothing requests" = lib.attrNames (lib.filterAttrs (_: vhost: !(certs ? ${vhost.certificate})) vhosts);
    "served names missing from their virtual host's certificate" = lib.concatLists (lib.mapAttrsToList (_: vhost:
      lib.optionals (certs ? ${vhost.certificate}) (lib.subtractLists (certNames certs.${vhost.certificate}) vhost.names))
    vhosts);
    "public certificate names missing from cloudflare-dyndns" = lib.subtractLists dyndns.domains publicNames;
  };

  actual = problemsIn {
    inherit (nook.services.nginx) virtualHosts;
    inherit (nook.security.acme) certs;
    dyndns = nook.services.cloudflare-dyndns;
  };
  # The gateway's users live in two modules; both must use its one address.
  gatewayProblems =
    lib.optional (nook.services.nginx.virtualHosts."cliproxy.local.bylisa.dev".locations."/".proxyPass != gateway) "the gateway's nginx upstream is not flake.lib.aiGatewayUrl"
    ++ lib.optional (nook.virtualisation.oci-containers.containers.cognee.environment.LLM_ENDPOINT != "${gateway}/v1") "Cognee does not call flake.lib.aiGatewayUrl";
  failures = lib.mapAttrsToList (rule: names: "${rule}: ${toString names}") (lib.filterAttrs (_: names: names != []) actual) ++ gatewayProblems;

  # A consistent fixture, then one break per rule; each must be reported.
  vhost = attrs:
    {
      serverName = null;
      serverAliases = [];
      useACMEHost = null;
      enableACME = false;
    }
    // attrs;
  fixture = {
    virtualHosts = {
      "app.bylisa.dev" = vhost {
        useACMEHost = "app.bylisa.dev";
        serverAliases = ["app.local.bylisa.dev"];
      };
      "renamed" = vhost {
        serverName = "app.bylisa.dev";
        useACMEHost = "app.bylisa.dev";
      };
      "own.bylisa.dev" = vhost {enableACME = true;};
      "plain.local.bylisa.dev" = vhost {};
    };
    certs = {
      "app.bylisa.dev" = {
        domain = "app.bylisa.dev";
        extraDomainNames = ["app.local.bylisa.dev"];
      };
      "own.bylisa.dev" = {
        domain = "own.bylisa.dev";
        extraDomainNames = [];
      };
    };
    dyndns = {
      enable = true;
      domains = ["app.bylisa.dev" "own.bylisa.dev"];
    };
  };
  reports = rule: change: (problemsIn (lib.recursiveUpdate fixture change)).${rule} != [];
  fixtureHolds =
    lib.all (names: names == []) (lib.attrValues (problemsIn fixture))
    && reports "cloudflare-dyndns is disabled" {dyndns.enable = false;}
    && reports "virtual hosts whose certificate nothing requests" {virtualHosts."new.local.bylisa.dev" = vhost {useACMEHost = "missing.local.bylisa.dev";};}
    && reports "served names missing from their virtual host's certificate" {virtualHosts."app.bylisa.dev".serverAliases = ["app.local.bylisa.dev" "extra.bylisa.dev"];}
    && reports "served names missing from their virtual host's certificate" {virtualHosts."renamed".serverName = "other.bylisa.dev";}
    && reports "public certificate names missing from cloudflare-dyndns" {dyndns.domains = ["app.bylisa.dev"];};
in {
  flake.checks.x86_64-linux.nook-wiring = withSystem "x86_64-linux" ({pkgs, ...}:
    assert lib.assertMsg fixtureHolds "nook-wiring: a fixture rule is no longer detected";
    assert lib.assertMsg (failures == []) "nook-wiring: ${lib.concatStringsSep "; " failures}";
      pkgs.runCommand "nook-wiring" {} ''
        touch "$out"
      '');
}
