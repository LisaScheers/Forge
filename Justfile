set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

age_identity := home_directory() / ".config/sops/age/keys.txt"

default:
    @just --list

# Format source modules and packages; flake.nix is generated separately.
[group('flake')]
fmt:
    nix shell --inputs-from . nixpkgs#alejandra -c alejandra modules packages

# Check source formatting without modifying files.
[group('flake')]
fmt-check:
    nix shell --inputs-from . nixpkgs#alejandra -c alejandra --check modules packages

# Run flake checks for the current system.
[group('flake')]
check:
    nix flake check

# Run flake checks on all supported systems; requires matching builders.
[group('flake')]
check-all:
    nix flake check --all-systems

# Update locked inputs.
[group('flake')]
update:
    nix flake update

# Regenerate flake.nix from feature-owned declarations.
[group('flake')]
write-flake:
    nix run .#write-flake

# Show flake outputs.
[group('flake')]
tree:
    nix flake show

# Enter the development shell.
[group('flake')]
dev:
    nix develop --no-pure-eval

# Switch the local host: Vega in Apple Terminal, Asterion in this terminal.
[group('system')]
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    case "$(uname -s):$(hostname -s)" in
      Darwin:vega)
        open -b com.apple.Terminal "{{ justfile_directory() }}/scripts/switch-vega.command"
        ;;
      Linux:asterion)
        /run/wrappers/bin/sudo nixos-rebuild switch --flake "path:{{ justfile_directory() }}#asterion"
        ;;
      *) echo 'just switch must run on Vega or Asterion.' >&2; exit 2 ;;
    esac

# Delete old generations and collect garbage in Apple Terminal.
[group('system')]
clean:
    /usr/bin/open -b com.apple.Terminal "{{ justfile_directory() }}/scripts/clean-vega.command"

# Apply Vega once to enable localhost SSH and its deployment key.
[group('system')]
vega-bootstrap: switch

# Build one host without activation; Nix may use configured remote builders.
[group('system')]
deploy-build host:
    #!/usr/bin/env bash
    set -euo pipefail
    case "$1" in
      nook|atlas) target_system=x86_64-linux ;;
      vega) target_system=aarch64-darwin ;;
      *) echo "unknown deploy host: $1" >&2; exit 2 ;;
    esac
    nix build ".#checks.$target_system.$1"

# Deploy one host in switch, dry, or test mode; Vega supports switch only.
[group('system')]
deploy host mode="switch":
    bash scripts/deploy.sh "$1" "$2"

# Deploy Atlas while keeping its updater paused for database maintenance.
[group('system')]
deploy-maintenance:
    bash scripts/deploy.sh atlas switch --maintenance

# For an existing installer use --phases disko,install,reboot; for passwords use --env-password.
# Repartition and install a host. Extra args go to nixos-anywhere.
[group('install')]
nixos-install target host *args:
    nix shell --inputs-from . nixpkgs#nixos-anywhere -c nixos-anywhere --flake ".#$2" --target-host "$1" "${@:3}"

# Import generated hardware into modules/hardware/<host>.nix before installation.
[group('install')]
hardware-config host source:
    bash scripts/import-hardware-config.sh "$1" "$2"

# Edit or create a secret; file paths are relative to modules/security/agenix.
[group('secrets')]
secret-edit file identity=age_identity:
    cd modules/security/agenix && RULES=./_secrets.nix agenix --edit "$1" --identity "$2"

# Re-encrypt secrets after changing recipients.nix.
[group('secrets')]
secret-rekey identity=age_identity:
    cd modules/security/agenix && RULES=./_secrets.nix agenix --rekey --identity "$1"

# Generate an age identity; age-keygen refuses to overwrite an existing key.
[group('secrets')]
age-keygen identity=age_identity:
    mkdir -p "$(dirname "$1")"
    age-keygen -o "$1"
    @echo "Add the public key to modules/security/agenix/pubkeys.nix and its rules to recipients.nix."
