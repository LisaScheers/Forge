{
  config,
  inputs,
  ...
}: {
  home.lisa-cli.imports = [config.home.t3-code];
  home.t3-code = inputs.t3-code-nix.homeModules.default;
  flake-file.inputs.t3-code-nix = {
    url = "github:LisaScheers/t3-code-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  home.lisa-vega = {
    programs.t3code = {
      enable = true;
      channel = "nightly";
      packageVariant = "prebuilt";
    };
  };
}
