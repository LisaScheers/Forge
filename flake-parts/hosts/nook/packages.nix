{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    map lib.lowPrio [
      git
      nano
    ];
}
