# --- flake-parts/shells/dev.nix
{
  lib,
  mkShell,
  nil,
  statix,
  deadnix,
  nix-output-monitor,
  nixfmt,
  markdownlint-cli,
  stdenv,
  writeShellScriptBin,
  gh,
  gh-dash,
  inputs',
  just,
  nix,
  nixos-anywhere,
  age,
  jq,
  sops,
  ssh-to-age,
  yq-go,
  symlinkJoin,
  writeShellApplication,
  pkgs,
  treefmt-wrapper ? null,
  dev-process ? null,
  pre-commit ? null,
}: let
  scripts = {
    rename-project = writeShellScriptBin "rename-project" ''
      find "$1" \( -type d -name .git -prune \) -o -type f -print0 | xargs -0 sed -i "s/forge/$2/g"
    '';
    nom-nix-wrappers = symlinkJoin {
      name = "nom-nix-wrappers";
      paths = [
        (writeShellApplication {
          name = "nix";
          text = ''
            if [ "$#" -eq 0 ]; then
              exec ${nix}/bin/nix
            fi

            case "$1" in
              build|shell|develop)
                exec ${nix-output-monitor}/bin/nom "$@"
                ;;
              *)
                exec ${nix}/bin/nix "$@"
                ;;
            esac
          '';
        })
        (writeShellApplication {
          name = "nix-build";
          text = ''
            exec ${nix-output-monitor}/bin/nom-build "$@"
          '';
        })
        (writeShellApplication {
          name = "nix-shell";
          text = ''
            exec ${nix-output-monitor}/bin/nom-shell "$@"
          '';
        })
      ];
    };
  };

  env = {
    SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
  };
in
  mkShell {
    packages = with pkgs;
      (lib.attrValues scripts)
      ++ (lib.optional (treefmt-wrapper != null) treefmt-wrapper)
      ++ (lib.optional (dev-process != null) dev-process)
      ++ [
        # -- NIX UTILS --
        scripts.nom-nix-wrappers
        nil # Yet another language server for Nix
        nixd # nixd
        statix # Lints and suggestions for the nix programming language
        deadnix # Find and remove unused code in .nix source files
        nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
        nixfmt # An opinionated formatter for Nix

        # -- GIT RELATED UTILS --
        # commitizen # Tool to create committing rules for projects, auto bump versions, and generate changelogs
        # cz-cli # The commitizen command line utility
        # fh # The official FlakeHub CLI
        gh # GitHub CLI tool
        gh-dash # Github Cli extension to display a dashboard with pull requests and issues

        # -- BASE LANG UTILS --
        markdownlint-cli # Command line interface for MarkdownLint
        # nodePackages.prettier # Prettier is an opinionated code formatter
        # typos # Source code spell checker

        # -- (YOUR) EXTRA PKGS --
        just
        sops
        age
        jq
        ssh-to-age
        yq-go
        nixos-anywhere
        inputs'.home-manager.packages.home-manager
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        inputs'.nix-darwin.packages.darwin-rebuild
      ];

    shellHook = ''
      ${lib.concatLines (lib.mapAttrsToList (name: value: "export ${name}=${value}") env)}
      ${lib.optionalString (pre-commit != null) pre-commit.installationScript}

      # Welcome splash text
      echo ""; echo -e "\e[1;37;42mWelcome to the forge devshell!\e[0m"; echo ""
    '';
  }
