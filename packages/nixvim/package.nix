{
  nixvim,
  pkgs,
  system,
  nixd,
  nixdSettings,
  oxfmt,
  oxlint,
  dotnetSdk,
  roslyn-ls,
  csharpier,
  netcoredbg,
}:
(nixvim.lib.evalNixvim {
  inherit system;
  modules = [
    ./config.nix
    # Share the flake's Nixpkgs so packages such as marksman's .NET come from the cache.
    {nixpkgs.pkgs = pkgs;}
  ];
  extraSpecialArgs = {inherit nixd nixdSettings oxfmt oxlint dotnetSdk roslyn-ls csharpier netcoredbg;};
}).config.build.package
