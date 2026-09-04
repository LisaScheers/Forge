{pkgs, ...}: {
  services.t3code = {
    enable = true;
    channel = "nightly";
    packageVariant = "prebuilt";
    host = "0.0.0.0";
    port = 3773;
    dataDirectory = "/srv/disks/projects/projects/.t3code";
    providerPackages = [
      pkgs.codex
    ];
  };
}
