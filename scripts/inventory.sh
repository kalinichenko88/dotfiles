#!/bin/bash

# Read-only drift report: what is installed but absent from the manifests.
# The reverse direction (manifest entries that are not installed) is doctor.sh.

set -euo pipefail

unset CDPATH
SCRIPT_DIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# The common library path is derived from this script at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

LC_ALL=C
export LC_ALL

trap dotfiles_cleanup_tmp EXIT
trap 'exit 130' HUP INT TERM

normalize_brewfile() {
  dotfiles_brewfile_records \
    | awk -F '\t' '{ printf "%s \"%s\"\n", $1, $2 }' \
    | sort -u
}

create_brew_snapshot() {
  local snapshot
  dotfiles_resolve_homebrew

  dotfiles_make_tmp dotfiles-inventory
  inventory_tmp=$DOTFILES_TMP
  snapshot=$inventory_tmp/Brewfile.source
  if ! "$DOTFILES_BREW_COMMAND" bundle dump --force --no-mas --file "$snapshot"; then
    dotfiles_die 'Homebrew inventory failed; no comparison was produced'
    return 1
  fi

  dotfiles_manifest Brewfile Brewfile.local | normalize_brewfile > "$inventory_tmp/desired"
  normalize_brewfile < "$snapshot" > "$inventory_tmp/actual"
}

print_brew_differences() {
  local kind desired_kind actual_kind
  for kind in tap brew cask; do
    desired_kind=$inventory_tmp/desired-$kind
    actual_kind=$inventory_tmp/actual-$kind
    grep "^$kind " "$inventory_tmp/desired" > "$desired_kind" || :
    grep "^$kind " "$inventory_tmp/actual" > "$actual_kind" || :

    printf '[%s manifest-only]\n' "$kind"
    comm -23 "$desired_kind" "$actual_kind"
    printf '[%s source-only]\n' "$kind"
    comm -13 "$desired_kind" "$actual_kind"
  done
}

print_node_inventory() {
  local desired_file installed_file node_root node_dir node_version
  desired_file=$inventory_tmp/node-desired
  installed_file=$inventory_tmp/node-installed
  node_root=$DOTFILES_TARGET_HOME/.nvm/versions/node

  grep -Ev '^[[:space:]]*(#|$)' "$DOTFILES_ROOT/setup/node-versions.txt" \
    | sort -u > "$desired_file"
  : > "$installed_file"
  if [ -d "$node_root" ]; then
    for node_dir in "$node_root"/*; do
      [ -d "$node_dir" ] || continue
      basename -- "$node_dir"
    done | sort -u > "$installed_file"
  fi

  comm -23 "$desired_file" "$installed_file" | while IFS= read -r node_version; do
    [ -n "$node_version" ] && printf 'node-manifest-only\t%s\n' "$node_version"
  done
  comm -13 "$desired_file" "$installed_file" | while IFS= read -r node_version; do
    [ -n "$node_version" ] && printf 'node-source-only\t%s\n' "$node_version"
  done
}

compare_inventory() {
  create_brew_snapshot

  printf 'Homebrew manifest comparison\n'
  print_brew_differences
  printf 'Runtime comparison\n'
  print_node_inventory
}

main() {
  case "${1:-}" in
    compare) compare_inventory ;;
    *)
      printf 'Usage: %s compare\n' "$0" >&2
      return 1
      ;;
  esac
}

main "$@"
