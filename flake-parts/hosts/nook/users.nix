{
  forge.modules.nixos.nook = let
    nixRemoteBuilderPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrYvuVU6UgbonZOq1DPLNVGzrXGnVMppeLFFjcB6k9g nix-remote-builder home-server";
  in {
    users.users = {
      root.hashedPassword = "!";

      lisa = {
        isNormalUser = true;
        description = "Lisa Scheers";
        extraGroups = ["wheel"];
        linger = true;
        openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ25EnARSLbWqw6UhR/6GyO2MsxMqE23W9VM495A2xQu"];
      };

      nix-remote-builder = {
        isNormalUser = true;
        description = "Nix remote builder";
        openssh.authorizedKeys.keys = [nixRemoteBuilderPublicKey];
      };
    };
  };
}
