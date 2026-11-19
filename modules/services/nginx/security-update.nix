let
  updateNginx = {
    lib,
    pkgs,
    ...
  }: let
    version = "1.30.7";
  in {
    # CVE-2026-123007 and CVE-2026-123633. Drop this override when the pin catches up.
    services.nginx.package = lib.mkIf (lib.versionOlder pkgs.nginxStable.version version) (
      pkgs.nginxStable.overrideAttrs {
        inherit version;
        nginxVersion = version;
        src = pkgs.fetchurl {
          url = "https://nginx.org/download/nginx-${version}.tar.gz";
          hash = "sha256-JWW1yDcFDpWPcPsPc8SOK8pFQq00n9NW9G+wxyYQvG4=";
        };
      }
    );
  };
in {
  nixos.atlas = updateNginx;
  nixos.nook = updateNginx;
}
