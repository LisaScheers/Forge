{
  config,
  inputs,
  ...
}: let
  system = "x86_64-linux";
in {
  network.atlas = {
    tailscale = "100.87.26.75";
    ssh = {
      user = "lisa";
      identityFile = "~/.ssh/lisa@atlas.pub";
    };
  };
  flake.nixosConfigurations.atlas = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [config.nixos.base config.nixos.atlas];
  };
  nixos.atlas = {
    networking.hostName = "atlas";
    imports = [config.nixos.atlas-hardware];
  };
  flake.checks.${system}.atlas = config.flake.nixosConfigurations.atlas.config.system.build.toplevel;
  deploy.hosts.atlas.sshUser = "lisa";
  ci.targets = [
    {
      target = "nixosConfigurations.\"atlas\".config.system.build.toplevel";
      inherit system;
      checks = ["atlas" "deploy-schema-atlas" "deploy-activate-atlas"];
    }
  ];
}
