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
assert_link "$TEST_ROOT/starship/starship.toml" "$target_home/.config/starship.toml"
assert_link "$TEST_ROOT/claude/skills/create-post" "$target_home/.claude/skills/create-post"
assert_link "$TEST_ROOT/claude/hooks/check-docs-before-commit.sh" \
  "$target_home/.claude/hooks/check-docs-before-commit.sh"

# Containment, not equality: docker login writes credentials into this file.
jq -e --slurpfile source "$TEST_ROOT/docker/config.json" 'contains($source[0])' \
  "$target_home/.docker/config.json" >/dev/null || \
  fail 'Docker config merge lost the tracked keys'

jq '. + {auths: {"ghcr.io": {auth: "token"}}}' \
  "$target_home/.docker/config.json" > "$tmp/docker-with-auth.json"
mv "$tmp/docker-with-auth.json" "$target_home/.docker/config.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config docker
assert_equals 'token' \
  "$(jq -r '.auths["ghcr.io"].auth' "$target_home/.docker/config.json")"
# The work identity is deliberately NOT created from the example: a placeholder
# address satisfies useConfigOnly, so Git would author work commits as it
# instead of refusing. Git ignores an includeIf whose path does not exist.
[ ! -e "$target_home/.config/git/gitconfig-work" ] || \
  fail 'bootstrap must not invent a work Git identity'
[ ! -e "$target_home/.config/git/gitconfig-local" ] || \
  fail 'bootstrap must not invent a local Git config'

jq -e --slurpfile hooks "$TEST_ROOT/claude/hooks-config.json" \
  '.hooks | contains($hooks[0])' "$target_home/.claude/settings.json" \
  >/dev/null || fail 'Claude hook settings were not merged'

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

# A hook the user owns, on an event this repository does not declare, must keep
# firing. Demanding exact equality here would delete it to stay green.
jq '.hooks.Stop = [{hooks: [{type: "command", command: "mine"}]}]' \
  "$target_home/.claude/settings.json" > "$tmp/settings-user-hook.json"
mv "$tmp/settings-user-hook.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-user-hook.out"
assert_equals 'mine' \
  "$(jq -r '.hooks.Stop[0].hooks[0].command' "$target_home/.claude/settings.json")"
jq -e --slurpfile hooks "$TEST_ROOT/claude/hooks-config.json" \
  '(.hooks | contains($hooks[0])) and .theme == "dark"' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude merge lost the tracked hooks or unrelated settings'

[ -z "$(find "$target_home/.claude" -maxdepth 1 -name 'settings.json.backup.*' \
  -print -quit)" ] || fail 'a no-op Claude merge created a backup'

# On an event this repository does declare, the tracked hooks win — and the
# file that gets rewritten is backed up first.
jq '.hooks.PreToolUse = [{matcher: "Bash", hooks: [{type: "command", command: "stale"}]}]' \
  "$target_home/.claude/settings.json" > "$tmp/settings-stale-hook.json"
mv "$tmp/settings-stale-hook.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-stale-hook.out"
jq -e --slurpfile hooks "$TEST_ROOT/claude/hooks-config.json" \
  '(.hooks | contains($hooks[0])) and .hooks.Stop[0].hooks[0].command == "mine"' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude merge did not restore the tracked hooks alongside the user hook'
settings_backup=$(find "$target_home/.claude" -maxdepth 1 \
  -name 'settings.json.backup.*' -print -quit)
[ -n "$settings_backup" ] || fail 'Claude merge did not back up the changed file'
assert_equals 'stale' \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$settings_backup")"

# With several identities in play, a guessed address is worse than an error.
grep -E '^[[:space:]]*useConfigOnly[[:space:]]*=[[:space:]]*true' \
  "$TEST_ROOT/git/gitconfig" >/dev/null || \
  fail 'git must refuse to invent an author identity'
grep -E '^[[:space:]]*email[[:space:]]*=' "$TEST_ROOT/git/gitconfig" >/dev/null && \
  fail 'gitconfig must not set a top-level email; identity comes from includeIf'

# Every project directory bootstrap creates must have a Git identity rule.
# Without one, commits there fall back to a guessed user@hostname address.
DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/dev-dirs" \
  "$TEST_ROOT/scripts/bootstrap.sh" config dev-dirs > "$tmp/dev-dirs.out"
project_dirs=$(sed -n 's/^info: created project directory: //p' "$tmp/dev-dirs.out")
[ -n "$project_dirs" ] || fail 'bootstrap created no project directories'
while IFS= read -r project_dir; do
  [ -n "$project_dir" ] || continue
  grep -F "gitdir:~/$project_dir/" "$TEST_ROOT/git/gitconfig" >/dev/null 2>&1 || \
    fail "no Git identity rule for $project_dir"
done <<EOF
$project_dirs
EOF

# gh owns its own config file — it writes state into it — so the preferences go
# in through `gh config set` and nothing must symlink over it.
[ -L "$target_home/.config/gh/config.yml" ] && \
  fail 'gh config must not be symlinked; gh writes to it'
grep -q 'gh config set' "$TEST_ROOT/scripts/bootstrap.sh" || \
  fail 'gh preferences are no longer applied'

# bootstrap.sh and doctor.sh keep two hand-maintained tables of the same
# source→target pairs. Rather than merge them, fail when they drift: anything
# bootstrap links must be something doctor checks.
grep -oE 'dotfiles_link [^ ]+' "$TEST_ROOT/scripts/bootstrap.sh" \
  | awk '{ print $2 }' | sort -u > "$tmp/linked-sources"
grep -oE 'check_link [^ ]+' "$TEST_ROOT/scripts/doctor.sh" \
  | awk '{ print $2 }' | sort -u > "$tmp/checked-sources"
unchecked=$(comm -23 "$tmp/linked-sources" "$tmp/checked-sources")
[ -z "$unchecked" ] || \
  fail "bootstrap links these but doctor never checks them: $unchecked"

pass 'configuration installation is complete, safe, and idempotent'
