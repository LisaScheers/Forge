{
  # nix-darwin does not manage /etc/hosts, so features add entries here and one
  # activation step owns the managed block, like NixOS's networking.hosts.
  darwin.base = {
    config,
    lib,
    ...
  }: let
    entries = lib.concatStringsSep "\n" (lib.mapAttrsToList (address: names: "${address} ${lib.concatStringsSep " " names}") config.forge.hosts);
  in {
    options.forge.hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "Extra /etc/hosts entries, keyed by address.";
    };
    config.system.activationScripts.postActivation.text = ''
      echo "configuring managed /etc/hosts entries..." >&2
      hosts_tmp=$(mktemp /tmp/nix-darwin-hosts.XXXXXX)
      # Also drop the per-feature blocks earlier generations wrote.
      /usr/bin/awk '
        /^# nix-darwin: (forge|internal\.bylisa\.dev|cliproxy) begin$/ { skip = 1; next }
        /^# nix-darwin: (forge|internal\.bylisa\.dev|cliproxy) end$/ { skip = 0; next }
        !skip { print }
      ' /etc/hosts > "$hosts_tmp"
      cat >> "$hosts_tmp" <<'EOF'
      # nix-darwin: forge begin
      ${entries}
      # nix-darwin: forge end
      EOF
      install -m 0644 "$hosts_tmp" /etc/hosts
      rm -f "$hosts_tmp"
    '';
  };
}
