{
  home.lisa-cli = {pkgs, ...}: {
    home.packages = [pkgs.dotnetCorePackages.sdk_10_0];
  };

  home.lisa = {
    lib,
    pkgs,
    ...
  }: {
    programs.zed-editor.extensions = ["csharp"];
    programs.zed-editor.userSettings = {
      languages.CSharp = {
        language_servers = ["roslyn" "!csharp-ls" "!omnisharp" "..."];
        formatter.external = {
          command = lib.getExe pkgs.csharpier;
          arguments = ["format" "--stdin-path" "{buffer_path}"];
        };
      };
      lsp.roslyn.binary = {
        path = lib.getExe pkgs.roslyn-ls;
        arguments = ["--stdio" "--autoLoadProjects"];
      };
    };
  };
}
