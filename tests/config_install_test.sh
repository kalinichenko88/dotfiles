#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
target_home=$tmp/home
mkdir -p "$target_home"

DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config

assert_link() {
  expected=$1
  target=$2
  [ -L "$target" ] || fail "expected symlink at $target"
  assert_equals "$expected" "$(readlink "$target")"
}

assert_link "$TEST_ROOT/git/gitconfig" "$target_home/.config/git/config"
assert_link "$TEST_ROOT/git/gitconfig-personal" "$target_home/.config/git/gitconfig-personal"
assert_link "$TEST_ROOT/zsh/zshrc" "$target_home/.zshrc"
assert_link "$TEST_ROOT/nvim" "$target_home/.config/nvim"
assert_link "$TEST_ROOT/wezterm.lua" "$target_home/.wezterm.lua"
assert_link "$TEST_ROOT/gh/config.yml" "$target_home/.config/gh/config.yml"
assert_link "$TEST_ROOT/starship/starship.toml" "$target_home/.config/starship.toml"
assert_link "$TEST_ROOT/claude/skills/create-post" "$target_home/.claude/skills/create-post"
assert_link "$TEST_ROOT/claude/hooks/check-docs-before-commit.sh" \
  "$target_home/.claude/hooks/check-docs-before-commit.sh"

cmp -s "$TEST_ROOT/docker/config.json" "$target_home/.docker/config.json" || \
  fail 'Docker config copy differs from the tracked source'
cmp -s "$TEST_ROOT/git/gitconfig-work.example" \
  "$target_home/.config/git/gitconfig-work" || fail 'work Git template is missing'
cmp -s "$TEST_ROOT/git/gitconfig-local.example" \
  "$target_home/.config/git/gitconfig-local" || fail 'local Git template is missing'

jq -e --slurpfile hooks "$TEST_ROOT/claude/hooks-config.json" \
  '.hooks == $hooks[0]' "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude hook settings were not merged'

# Add a non-hook key, then verify a second install preserves it without backups.
jq '. + {theme: "dark"}' "$target_home/.claude/settings.json" > "$tmp/settings-with-theme.json"
mv "$tmp/settings-with-theme.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config
assert_equals 'dark' "$(jq -r '.theme' "$target_home/.claude/settings.json")"
[ -z "$(find "$target_home" -name '*.backup.*' -print -quit)" ] || \
  fail 'idempotent config install created a backup'

rm "$target_home/.zshrc"
printf 'local zsh\n' > "$target_home/.zshrc"
if DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/conflict.out" 2> "$tmp/conflict.err"; then
  fail 'config conflict must fail without FORCE=1'
fi
assert_equals 'local zsh' "$(cat "$target_home/.zshrc")"

FORCE=1 DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config
assert_link "$TEST_ROOT/zsh/zshrc" "$target_home/.zshrc"
zsh_backup=$(find "$target_home" -maxdepth 1 -name '.zshrc.backup.*' -print -quit)
[ -n "$zsh_backup" ] || fail 'forced config install did not back up .zshrc'
assert_equals 'local zsh' "$(cat "$zsh_backup")"

jq '.hooks = {unexpected: true}' "$target_home/.claude/settings.json" \
  > "$tmp/settings-conflict.json"
mv "$tmp/settings-conflict.json" "$target_home/.claude/settings.json"
if DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-conflict.out" 2> "$tmp/claude-conflict.err"; then
  fail 'changed Claude settings must require FORCE=1'
fi
assert_equals 'true' "$(jq -r '.hooks.unexpected' "$target_home/.claude/settings.json")"

FORCE=1 DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-force.out"
jq -e --slurpfile hooks "$TEST_ROOT/claude/hooks-config.json" \
  '.hooks == $hooks[0] and .theme == "dark"' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'forced Claude merge did not preserve non-hook settings'
settings_backup=$(find "$target_home/.claude" -maxdepth 1 \
  -name 'settings.json.backup.*' -print -quit)
[ -n "$settings_backup" ] || fail 'forced Claude merge did not create a backup'
assert_equals 'true' "$(jq -r '.hooks.unexpected' "$settings_backup")"

pass 'configuration installation is complete, safe, and idempotent'
