{config, ...}: let
  inherit (config.flake.lib) nixdSettings;
in {
  home.lisa = {
    lib,
    pkgs,
    ...
  }: {
    programs.claude-code = {
      enable = true;
      mutableSettings = true;
      settings = {
        # Servers from a repository's .mcp.json start only after approval.
        enableAllProjectMcpServers = false;
        # Cognee holds memory across sessions, as for Codex, whose memories are off too.
        autoMemoryEnabled = false;
        # `@` completion: every file under the project, including untracked ones,
        # ranked by fzf's fuzzy match against what has been typed.
        fileSuggestion = {
          type = "command";
          command = lib.getExe (pkgs.writeShellApplication {
            name = "claude-file-suggestion";
            runtimeInputs = [pkgs.coreutils pkgs.fd pkgs.fzf pkgs.jq];
            text = builtins.readFile ./claude-code/file-suggestion.sh;
          });
        };
        # Model, context used and plan limits under the prompt, as Codex shows them.
        statusLine = {
          type = "command";
          command = lib.getExe (pkgs.writeShellApplication {
            name = "claude-status-line";
            runtimeInputs = [pkgs.jq];
            text = builtins.readFile ./claude-code/statusline.sh;
          });
          padding = 0;
        };
        env = {
          # Nix installs and updates Claude Code.
          DISABLE_AUTOUPDATER = "1";
          # AGENTS.md: delegated agents do not start their own.
          CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "1";
        };
      };
      # Diagnostics and navigation after each edit, in the languages Forge's tools use.
      lspServers = {
        nix = {
          command = lib.getExe pkgs.nixd;
          extensionToLanguage.".nix" = "nix";
          settings.nixd = nixdSettings pkgs;
        };
        python = {
          command = lib.getExe pkgs.ruff;
          args = ["server"];
          extensionToLanguage.".py" = "python";
        };
        typescript = {
          command = lib.getExe pkgs.typescript-language-server;
          args = ["--stdio"];
          extensionToLanguage = {
            ".ts" = "typescript";
            ".tsx" = "typescriptreact";
            ".js" = "javascript";
            ".jsx" = "javascriptreact";
            ".mjs" = "javascript";
          };
        };
        bash = {
          command = lib.getExe pkgs.bash-language-server;
          args = ["start"];
          extensionToLanguage = {
            ".sh" = "shellscript";
            ".bash" = "shellscript";
          };
        };
      };
    };
  };
}
