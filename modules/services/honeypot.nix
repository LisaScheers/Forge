{inputs, ...}: {
  flake-file.inputs.nix-honeypot = {
    url = "github:LisaScheers/nix-honeypot";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      import-tree.follows = "import-tree";
    };
  };

  nixos.atlas = {
    imports = [inputs.nix-honeypot.nixosModules.default];
    services.honeypot = {
      enable = true;
      openFirewall = true;
      # Forgejo SSH uses 2222, LiveKit JWT uses 8080, and Authentik Redis uses 6379.
      services.ssh.port = 2223;
      services.http.port = 8081;
      services.redis.port = 6380;
    };
  };
}
