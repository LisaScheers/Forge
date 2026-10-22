{
  nixvim,
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
  modules = [./config.nix];
  extraSpecialArgs = {inherit nixd nixdSettings oxfmt oxlint dotnetSdk roslyn-ls csharpier netcoredbg;};
}).config.build.package
