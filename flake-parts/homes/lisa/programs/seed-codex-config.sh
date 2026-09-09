#!/usr/bin/env bash
set -euo pipefail

config_path=$1
defaults_path=$2

# Preserve app edits on later activations. Convert the old Home Manager link
# before linkGeneration removes it, retaining its current contents.
if [[ -L "$config_path" ]]; then
  case "$(readlink "$config_path")" in
    /nix/store/*) source_path=$config_path ;;
    *) exit 0 ;;
  esac
elif [[ -e "$config_path" ]]; then
  exit 0
else
  source_path=$defaults_path
fi

mkdir -p "$(dirname "$config_path")"
temporary_path=$(mktemp "${config_path}.XXXXXX")
trap 'rm -f "$temporary_path"' EXIT
cat "$source_path" > "$temporary_path"
chmod 600 "$temporary_path"
mv -f "$temporary_path" "$config_path"
