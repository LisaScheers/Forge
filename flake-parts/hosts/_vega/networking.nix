{...}: {
  system.activationScripts.postActivation.text = ''
    echo "configuring internal.bylisa.dev host records..." >&2

    hosts_file=/etc/hosts
    begin_marker="# nix-darwin: internal.bylisa.dev begin"
    end_marker="# nix-darwin: internal.bylisa.dev end"
    tmp_file=$(mktemp /tmp/nix-darwin-hosts.XXXXXX)
    trap 'rm -f "$tmp_file"' EXIT

    if [ -f "$hosts_file" ]; then
      awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        skip != 1 { print }
      ' "$hosts_file" > "$tmp_file"
    else
      : > "$tmp_file"
    fi

    cat >> "$tmp_file" <<'EOF'

    # nix-darwin: internal.bylisa.dev begin
    2a02:1810:515:c682::1 internal.bylisa.dev
    192.168.50.1 internal.bylisa.dev
    # nix-darwin: internal.bylisa.dev end
    EOF

    install -m 0644 "$tmp_file" "$hosts_file"
    rm -f "$tmp_file"
    trap - EXIT
  '';
}
