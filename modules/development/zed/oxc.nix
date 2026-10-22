{
  home.lisa = {
    lib,
    pkgs,
    ...
  }: let
    scriptLanguages = ["JavaScript" "JSX" "TypeScript" "TSX" "Vue.js"];
    formatLanguages =
      scriptLanguages
      ++ [
        "JSON"
        "JSON5"
        "JSONC"
        "HTML"
        "Angular"
        "CSS"
        "SCSS"
        "LESS"
        "GraphQL"
        "Handlebars"
        "Markdown"
        "MDX"
        "YAML"
        "TOML"
      ];
  in {
    programs.zed-editor.userSettings = {
      languages =
        lib.genAttrs formatLanguages (language: {
          formatter.language_server.name = "oxfmt";
          language_servers =
            ["oxfmt"]
            ++ lib.optional (builtins.elem language scriptLanguages) "oxlint"
            ++ ["..."];
        })
        // lib.genAttrs ["Astro" "Svelte"] (_: {
          language_servers = ["oxlint" "..."];
        });
      lsp = {
        oxfmt.binary = {
          path = lib.getExe pkgs.oxfmt;
          arguments = ["--lsp"];
        };
        oxlint.binary = {
          path = lib.getExe pkgs.oxlint;
          arguments = ["--lsp"];
        };
      };
    };
  };
}
