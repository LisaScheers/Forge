{
  config,
  inputs,
  pkgs,
  ...
}: let
  domain = "tack.bylisa.dev";
  package = pkgs.callPackage "${inputs.pony-tack}/flake-parts/pkgs/pony-tack.nix" {
    src = inputs.pony-tack;
  };
in {
  imports = [
    (import "${inputs.pony-tack}/flake-parts/modules/nixos/pony-tack.nix" {
      localFlake.packages.${pkgs.stdenv.hostPlatform.system}.default = package;
    })
  ];

  age.secrets = {
    pony-tack-deploy-key = {
      file = ../../agenix/secrets/atlas/pony-tack-deploy-key.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    pony-tack-env = {
      file = ../../agenix/secrets/atlas/pony-tack-env.age;
      owner = "root";
      group = "pony-tack";
      mode = "0440";
    };
  };

  programs.ssh = {
    extraConfig = ''
      Host ssh.github.com
        HostName ssh.github.com
        Port 443
        User git
        IdentityFile ${config.age.secrets.pony-tack-deploy-key.path}
        IdentitiesOnly yes
        StrictHostKeyChecking yes
    '';
    knownHosts.github-ssh = {
      hostNames = [
        "ssh.github.com"
        "[ssh.github.com]:443"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  services.pony-tack = {
    enable = true;
    inherit domain;
    environmentFile = config.age.secrets.pony-tack-env.path;
    inherit package;
    nginx = {
      enable = true;
      enableACME = true;
      openFirewall = true;
    };
  };

  systemd.services.pony-tack.restartTriggers = [
    ../../agenix/secrets/atlas/pony-tack-env.age
  ];
}
