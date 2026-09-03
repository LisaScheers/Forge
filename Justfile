# Justfile for nix-config automation

# Default recipe - show available commands
default:
    @just --list

# Format all Nix files using alejandra
fmt:
    nix fmt

# Apply Vega once before its first deploy-rs activation.
# This enables localhost SSH and installs the deployment key.
vega-bootstrap:
    sudo darwin-rebuild switch --flake .#vega

# Install the home server with nixos-anywhere.
# WARNING: this repartitions and formats the disk configured in config.nix.
nixos-install target host="home-server":
    nix develop --no-pure-eval --command nixos-anywhere --generate-hardware-config nixos-generate-config ./modules/hosts/"{{host}}"/_hardware-configuration.nix --flake .#"{{host}}" --target-host "{{target}}"

# Install using password auth. Set SSHPASS in the environment before running this.
# WARNING: this repartitions and formats the disk configured in config.nix.
nixos-install-password target host="home-server":
    nix develop --no-pure-eval --command nixos-anywhere --env-password --generate-hardware-config nixos-generate-config ./modules/hosts/"{{host}}"/_hardware-configuration.nix --flake .#"{{host}}" --target-host "{{target}}"

# Install from an already-booted NixOS installer environment, skipping kexec.
# WARNING: this repartitions and formats the disks configured in config.nix.
nixos-install-from-installer target host="home-server":
    nix develop --no-pure-eval --command nixos-anywhere --phases disko,install,reboot --generate-hardware-config nixos-generate-config ./modules/hosts/"{{host}}"/_hardware-configuration.nix --flake .#"{{host}}" --target-host "{{target}}"

# Install from an already-booted NixOS installer environment with password auth.
# WARNING: this repartitions and formats the disks configured in config.nix.
nixos-install-from-installer-password target host="home-server":
    nix develop --no-pure-eval --command nixos-anywhere --env-password --phases disko,install,reboot --generate-hardware-config nixos-generate-config ./modules/hosts/"{{host}}"/_hardware-configuration.nix --flake .#"{{host}}" --target-host "{{target}}"

# Install from an already-booted NixOS installer environment with a specific SSH key.
# WARNING: this repartitions and formats the disks configured in config.nix.
nixos-install-from-installer-key target identity="/tmp/home-server-installer-ed25519" host="home-server":
    nix develop --no-pure-eval --command nixos-anywhere -i "{{identity}}" --phases disko,install,reboot --generate-hardware-config nixos-generate-config ./modules/hosts/"{{host}}"/_hardware-configuration.nix --flake .#"{{host}}" --target-host "{{target}}"

# Edit or create an agenix secret. Paths are relative to flake-parts/agenix.
secret-edit file identity="/Users/lisa/.config/sops/age/keys.txt":
    cd flake-parts/agenix && RULES=./secrets.nix agenix --edit "{{file}}" --identity "{{identity}}"

# Re-encrypt all agenix secrets after changing recipients in secrets.nix.
secret-rekey identity="/Users/lisa/.config/sops/age/keys.txt":
    cd flake-parts/agenix && RULES=./secrets.nix agenix --rekey --identity "{{identity}}"

# Check flake
check:
    nix flake check

# Check flake on every declared supported system when matching builders are available
check-all:
    nix flake check --all-systems

# Check formatting without modifying files
fmt-check:
    nix fmt -- --check

# Update flake inputs
update:
    nix flake update

# Regenerate flake.nix from flake-file declarations
write-flake:
    nix run .#write-flake

# Show flake tree
tree:
    nix flake show

# Enter development shell
dev:
    nix develop --no-pure-eval

# Build one host without activating it.
# Nix may use the remote builders declared by this flake.
deploy-build host:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{host}}" in
      nook|atlas)
        nix build ".#nixosConfigurations.{{host}}.config.system.build.toplevel"
        ;;
      vega)
        nix build ".#darwinConfigurations.vega.system"
        ;;
      *)
        echo "unknown deploy host: {{host}}" >&2
        exit 2
        ;;
    esac

# Deploy exactly one host. Modes are switch, dry, and test.
# Vega supports switch only and always targets localhost.
deploy host mode="switch":
    #!/usr/bin/env bash
    set -euo pipefail

    host="{{host}}"
    mode="{{mode}}"
    case "$host" in
      nook|atlas|vega) ;;
      *)
        echo "unknown deploy host: $host" >&2
        exit 2
        ;;
    esac

    deploy_args=(--skip-checks)
    case "$mode" in
      switch) ;;
      dry) deploy_args+=(--dry-activate) ;;
      test) deploy_args+=(--test) ;;
      *)
        echo "unknown deploy mode: $mode" >&2
        exit 2
        ;;
    esac

    if [[ "$host" == "vega" ]]; then
      if [[ "$mode" != "switch" ]]; then
        echo "deploy-rs does not provide useful dry or test activation for nix-darwin" >&2
        exit 2
      fi
      if [[ "$(hostname -s)" != "vega" ]]; then
        echo "Vega can only be deployed manually from Vega" >&2
        exit 2
      fi
    fi

    if [[ "$host" == "atlas" ]]; then
      if [[ -n "$(git status --porcelain)" ]]; then
        echo "Atlas deploys require a clean worktree" >&2
        exit 1
      fi

      git fetch --quiet origin main
      if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
        echo "Atlas deploys require HEAD to match origin/main" >&2
        exit 1
      fi
    fi

    case "$host" in
      nook|atlas) target_system="x86_64-linux" ;;
      vega) target_system="aarch64-darwin" ;;
    esac
    nix build --no-link \
      ".#checks.$target_system.deploy-schema-$host" \
      ".#checks.$target_system.deploy-activate-$host" \
      ".#checks.$target_system.$host"

    atlas_timer_needs_restart=0
    atlas_deploy_started=0
    restart_atlas_timer() {
      exit_status=$?
      trap - EXIT
      if [[ "$atlas_timer_needs_restart" == "1" ]]; then
        if [[ "$atlas_deploy_started" == "1" && "$exit_status" != "0" ]]; then
          echo "Atlas deployment failed; its auto-update timer remains stopped" >&2
          echo "after fixing or reverting main, restart it with:" >&2
          echo "  ssh atlas sudo systemctl start nix-auto-sync-update.timer" >&2
        elif ! ssh atlas sudo systemctl start nix-auto-sync-update.timer; then
          echo "failed to restart Atlas auto-update timer" >&2
          exit_status=1
        fi
      fi
      exit "$exit_status"
    }
    trap restart_atlas_timer EXIT

    if [[ "$host" == "atlas" ]]; then
      atlas_timer_needs_restart=1
      ssh atlas sudo systemctl stop nix-auto-sync-update.timer
      update_state="$(ssh atlas systemctl show --property=ActiveState --value nix-auto-sync-update.service)"
      if [[ "$update_state" != "inactive" ]]; then
        echo "Atlas auto-update state is $update_state; it was not deployed" >&2
        exit 1
      fi
      reboot_state="$(ssh atlas systemctl show --property=ActiveState --value nix-auto-sync-update-reboot.timer)"
      if [[ "$reboot_state" != "inactive" ]]; then
        echo "Atlas reboot timer state is $reboot_state; it was not deployed" >&2
        exit 1
      fi

      # Close the race where main changes while the closures are building.
      git fetch --quiet origin main
      if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
        echo "origin/main changed while building; Atlas was not deployed" >&2
        exit 1
      fi
    fi

    # Forge's full flake check has unrelated baseline failures. The three
    # target checks above are the deployment gate.
    if [[ "$host" == "atlas" ]]; then
      atlas_deploy_started=1
    fi
    nix run .#deploy -- "${deploy_args[@]}" ".#$host"

# Generate an age identity for agenix (if needed).
age-keygen:
    @echo "Generating age identity for agenix..."
    @mkdir -p ~/.config/sops/age
    @age-keygen -o ~/.config/sops/age/keys.txt
    @echo "Age key generated at ~/.config/sops/age/keys.txt"
    @echo "Add the public key to flake-parts/agenix/pubkeys.nix and the relevant rules in flake-parts/agenix/secrets.nix"
