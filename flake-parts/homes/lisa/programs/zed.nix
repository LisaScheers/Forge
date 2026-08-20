{
  pkgs,
  lib,
  system,
  ...
}: let
  isDarwin = (lib.systems.elaborate system).isDarwin;

  extentions = import ./zed/extensions.nix;
  terminal = import ./zed/terminal.nix;
  lsp = import ./zed/lsp.nix {inherit pkgs;};
  settings = import ./zed/settings.nix;
in {
  programs.zed-editor = {
    enable = isDarwin;
    extensions = extentions;
    userSettings =
      settings
      // {
        terminal = terminal;
        lsp = lsp;
      };
  };
}
