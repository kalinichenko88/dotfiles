#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/zsh-config.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
tracked_zsh=$tmp/tracked-zsh
mutated_zsh=$tmp/mutated-zsh
mkdir -p "$tracked_zsh" "$mutated_zsh" \
  "$tmp/home/.openclaw/completions" "$tmp/bin"
git -C "$TEST_ROOT" ls-files 'zsh/zshrc' 'zsh/*.zsh' \
  > "$tmp/tracked-zsh-files"

# grep, not ripgrep: this has to run on a bare macOS runner. A missing tool
# used to look exactly like a clean result here.
assert_tracked_zsh_is_portable() {
  local source_root tracked_file grep_status
  source_root=$1

  while IFS= read -r tracked_file; do
    grep -nE '/Users/[^/]+/|\.bun/(bin|_bun)|BUN_INSTALL|python@[0-9]' \
      "$source_root/$tracked_file" && return 1
    grep_status=$?
    [ "$grep_status" -eq 1 ] || \
      fail "portability check could not read $tracked_file"
  done < "$tmp/tracked-zsh-files"
}

if ! assert_tracked_zsh_is_portable "$TEST_ROOT"; then
  fail 'non-portable Zsh path remains'
fi

local_source_count=$(grep -cE 'source .*local\.zsh' "$TEST_ROOT/zsh/zshrc" || true)
assert_equals '1' "$local_source_count"
# $HOME must remain literal in the tracked configuration.
# shellcheck disable=SC2016
assert_file_contains "$TEST_ROOT/zsh/path.zsh" 'export NVM_DIR="$HOME/.nvm"'

# One file per invocation: `zsh -n a b` parses only a and hands b to it as $1,
# so every extra argument was silently unchecked.
while IFS= read -r tracked_file; do
  zsh -n "$TEST_ROOT/$tracked_file" || fail "zsh syntax error in $tracked_file"
done < "$tmp/tracked-zsh-files"

# The Brewfile installs a keg-only python, so the unversioned python and pip
# only exist if libexec is on PATH — without a pinned version in the path.
if grep -q '^brew "python@' "$TEST_ROOT/Brewfile"; then
  assert_file_contains "$TEST_ROOT/zsh/path.zsh" '/opt/homebrew/opt/python@*/libexec/bin'
fi

while IFS= read -r tracked_file; do
  [ "$tracked_file" != 'zsh/local.zsh' ] || continue
  cp "$TEST_ROOT/$tracked_file" "$tracked_zsh/${tracked_file##*/}"
  cp "$TEST_ROOT/$tracked_file" "$mutated_zsh/${tracked_file##*/}"
done < "$tmp/tracked-zsh-files"

ignored_zsh=$tmp/ignored-zsh
mkdir -p "$ignored_zsh/zsh"
while IFS= read -r tracked_file; do
  cp "$TEST_ROOT/$tracked_file" "$ignored_zsh/$tracked_file"
done < "$tmp/tracked-zsh-files"
printf '%s\n' \
  'source /Users/example/.openclaw/completions/openclaw.zsh' \
  > "$ignored_zsh/zsh/local.zsh"
if ! assert_tracked_zsh_is_portable "$ignored_zsh"; then
  fail 'ignored local.zsh affected tracked Zsh portability check'
fi

# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf sourced > "$COMPLETION_MARKER"\n' > \
  "$tmp/home/.openclaw/completions/openclaw.zsh"
printf '#!/bin/sh\nprintf ":\\n"\n' > "$tmp/bin/starship"
chmod +x "$tmp/bin/starship"

# The payload must remain literal until the mutated Zsh configuration is sourced.
# shellcheck disable=SC2016
printf '%s\n' \
  'openclaw_completion="$HOME/.openclaw/completions/openclaw.zsh"' \
  '[[ -r "$openclaw_completion" ]] && source "$openclaw_completion"' \
  'unset openclaw_completion' >> "$mutated_zsh/zshrc"

if HOME="$tmp/home" COMPLETION_MARKER="$tmp/mutated-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c \
  'source "$1"; [ ! -e "$COMPLETION_MARKER" ]' \
  zsh "$mutated_zsh/zshrc"; then
  fail 'OpenClaw-loader mutation was not detected'
fi
[ -e "$tmp/mutated-marker" ] || \
  fail 'OpenClaw-loader mutation did not exercise the completion fixture'

HOME="$tmp/home" COMPLETION_MARKER="$tmp/completion-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c 'source "$1"; :' zsh "$tracked_zsh/zshrc"
[ ! -e "$tmp/completion-marker" ] || \
  fail 'tracked Zsh configuration must not source OpenClaw completions'

pass 'tracked Zsh configuration is portable'
