{
  writeShellApplication,
  coreutils,
  gawk,
}:
writeShellApplication {
  name = "filter-apple-ca-roots";
  runtimeInputs = [coreutils gawk];
  text = ''
    if [[ $# != 1 || ! -f "$1" || -L "$1" ]]; then
      echo "Usage: filter-apple-ca-roots <regular Apple CA bundle file>" >&2
      exit 1
    fi
    bundle_file=$1
    filtered_file=$(mktemp "$bundle_file.XXXXXX")
    trap 'rm -f "$filtered_file"' EXIT

    # Preserve owner and permissions; rename on the same filesystem is atomic.
    cp -p -- "$bundle_file" "$filtered_file"
    awk -f ${../../tools/certificates/remove-compromised-roots.awk} \
      "$bundle_file" > "$filtered_file"
    if cmp -s -- "$bundle_file" "$filtered_file"; then
      exit 0
    fi
    if ! awk '/^-----BEGIN CERTIFICATE-----$/ { found = 1; exit } END { exit !found }' "$filtered_file"; then
      echo "Refusing to replace a CA bundle with no remaining certificates" >&2
      exit 1
    fi
    if [[ ! -e "$bundle_file.before-emudhra" ]]; then
      cp -p -- "$bundle_file" "$bundle_file.before-emudhra"
    fi
    mv -f -- "$filtered_file" "$bundle_file"
  '';
}
