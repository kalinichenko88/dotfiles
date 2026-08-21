#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

# shellcheck disable=SC1091
. "$TEST_ROOT/scripts/lib/common.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-common.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/repo/zsh" "$tmp/repo/docker" "$tmp/home"
printf 'source\n' > "$tmp/repo/zsh/zshrc"
printf '{"context":"colima"}\n' > "$tmp/repo/docker/config.json"

# Exported because the sourced library reads them, and because shellcheck 0.11
# calls a bare assignment unused — the CI image ships an older build that does
# not, so the lint gate was stricter locally than in CI.
export DOTFILES_ROOT=$tmp/repo
export DOTFILES_TARGET_HOME=$tmp/home

dotfiles_link zsh/zshrc "$tmp/home/.zshrc"
assert_equals "$tmp/repo/zsh/zshrc" "$(readlink "$tmp/home/.zshrc")"

target=caller-target
relative_source=caller-source
source_path=caller-path
dotfiles_link zsh/zshrc "$tmp/home/.zshrc"
assert_equals 'caller-target' "$target"
assert_equals 'caller-source' "$relative_source"
assert_equals 'caller-path' "$source_path"

dotfiles_link zsh/zshrc "$tmp/home/.zshrc"
[ -L "$tmp/home/.zshrc" ] || fail 'idempotent link was replaced'

rm "$tmp/home/.zshrc"
printf 'local\n' > "$tmp/home/.zshrc"
if dotfiles_link zsh/zshrc "$tmp/home/.zshrc"; then
  fail 'a conflicting file must fail without FORCE=1'
fi
assert_equals 'local' "$(cat "$tmp/home/.zshrc")"

FORCE=1 dotfiles_link zsh/zshrc "$tmp/home/.zshrc"
[ -L "$tmp/home/.zshrc" ] || fail 'forced link was not installed'
backup=$(find "$tmp/home" -maxdepth 1 -name '.zshrc.backup.*' -print | head -n 1)
[ -n "$backup" ] || fail 'forced link backup is missing'
assert_equals 'local' "$(cat "$backup")"

ln -s "$tmp/missing" "$tmp/home/.broken"
if dotfiles_link zsh/zshrc "$tmp/home/.broken"; then
  fail 'a broken symlink must be treated as a conflict'
fi
[ -L "$tmp/home/.broken" ] || fail 'broken symlink was changed without force'

dotfiles_copy docker/config.json "$tmp/home/.docker/config.json"
assert_equals '{"context":"colima"}' "$(cat "$tmp/home/.docker/config.json")"
dotfiles_copy docker/config.json "$tmp/home/.docker/config.json"

printf 'local docker\n' > "$tmp/home/.docker/config.json"
if dotfiles_copy docker/config.json "$tmp/home/.docker/config.json"; then
  fail 'a conflicting copy must fail without FORCE=1'
fi
FORCE=1 dotfiles_copy docker/config.json "$tmp/home/.docker/config.json"
assert_equals '{"context":"colima"}' "$(cat "$tmp/home/.docker/config.json")"
copy_backup=$(find "$tmp/home/.docker" -maxdepth 1 -name 'config.json.backup.*' -print | head -n 1)
[ -n "$copy_backup" ] || fail 'forced copy backup is missing'
assert_equals 'local docker' "$(cat "$copy_backup")"

DRY_RUN=1 dotfiles_link zsh/zshrc "$tmp/home/dry/.zshrc" >/dev/null
[ ! -e "$tmp/home/dry/.zshrc" ] || fail 'dry run mutated the target home'

printf 'cask "shared"\n' > "$tmp/repo/Brewfile"
assert_equals 'cask "shared"' "$(dotfiles_manifest Brewfile Brewfile.local | grep .)"
printf 'cask "machine-only"\n' > "$tmp/repo/Brewfile.local"
assert_equals 'cask "shared"
cask "machine-only"' "$(dotfiles_manifest Brewfile Brewfile.local | grep .)"

# A tracked manifest without a trailing newline must not swallow its own last
# entry and the local file's first one.
printf 'cask "shared"' > "$tmp/repo/Brewfile"
assert_equals 'cask "shared"
cask "machine-only"' "$(dotfiles_manifest Brewfile Brewfile.local | grep .)"

pass 'shared bootstrap primitives are safe and idempotent'
