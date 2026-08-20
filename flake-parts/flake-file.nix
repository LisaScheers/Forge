{lib, ...}: {
  flake-file = {
    description = "Multi-host Nix configuration for Darwin and NixOS";

    inputs = {
      catppuccin = {
        url = "github:catppuccin/nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      zed = {
        url = "github:zed-industries/zed";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      t3-code-nix = {
        url = "github:LisaScheers/t3-code-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    nixConfig = {
      extra-substituters = ["https://zed.cachix.org"];
      extra-trusted-public-keys = [
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      ];
    };

    do-not-edit = lib.concatLines (
      map (line: "# ${line}") (
        lib.splitString "\n" ''
          This flake.nix file is auto-generated.
          The source of truth is merged from flake-parts modules under flake-parts/.
          Regenerate with: nix run .#write-flake
          https://flake-file.denful.dev/''
      )
    );
  };
  debug = true;
}
