{config, ...}: let
  features = config.nixos;
in {
  nixos.atlas = {config, ...}: {
    imports = [features.matrix-volume];
    matrix.volume = {
      enable = true;
      device = "/dev/disk/by-id/scsi-0HC_Volume_107199635";
    };
    services.nginx.virtualHosts."${config.matrix.subDomain}.${config.matrix.rootDomain}".locations."/_matrix".extraConfig = ''
      client_max_body_size 512m;
    '';
  };
}
