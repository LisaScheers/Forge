if [[ "${1:-}" != get ]]; then
  exit 0
fi

protocol=
host=
while IFS='=' read -r key value && [[ -n "$key" ]]; do
  case "$key" in
    protocol) protocol=$value ;;
    host) host=$value ;;
  esac
done

[[ "$protocol" == https && "$host" == git.bylisa.dev ]] || exit 0

# fj refreshes expired OAuth logins and persists rotated tokens before returning.
fj --host https://git.bylisa.dev whoami >/dev/null

if [[ "$OSTYPE" == darwin* ]]; then
  keys_file="$HOME/Library/Application Support/forgejo-cli.forgejo-cli/keys.json"
else
  keys_file="${XDG_DATA_HOME:-$HOME/.local/share}/forgejo-cli/keys.json"
fi

token=$(jq -er '.hosts["git.bylisa.dev"].token | select(type == "string" and length > 0) | select(test("[\r\n]") | not)' "$keys_file")
printf 'username=Lisa\npassword=%s\n\n' "$token"
