#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

HOOK=$TEST_ROOT/claude/hooks/check-docs-before-push.sh
FIXTURES=$TEST_ROOT/tests/fixtures/hook-commands

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-hooks.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# The hook only speaks up in a repository that has documentation to review.
git init -q "$tmp/repo"
: > "$tmp/repo/README.md"
git -C "$tmp/repo" add README.md

# Every call gets its own session, so the flag file one attempt leaves behind
# never decides the next assertion.
run_hook() {
  local session
  session="dotfiles-hooks-test-$$-$RANDOM"
  jq -n --arg c "$1" --arg s "$session" --arg cwd "$tmp/repo" \
    '{tool_input: {command: $c}, session_id: $s, cwd: $cwd}' | bash "$HOOK"
  rm -f "/tmp/claude-docs-checked-$session"
}

assert_denies() {
  case $(run_hook "$2") in
    *'"deny"'*) pass "$1" ;;
    *) fail "$1" ;;
  esac
}

assert_allows() {
  case $(run_hook "$2") in
    '') pass "$1" ;;
    *) fail "$1" ;;
  esac
}

assert_denies 'a bare push is stopped' 'git push'
assert_denies 'a push chained after a commit is stopped' 'git commit -m x && git push'
assert_denies 'a push on its own line is stopped' "$(printf 'cd /repo\ngit push origin main')"

# Recorded payloads, both observed reaching the hook. A heredoc terminator ends
# the line, so a commit message written through one always leaves the push on a
# line of its own — and a document written through one can name the command on a
# line of its own while pushing nothing.
assert_denies 'a push after a heredoc commit message is stopped' \
  "$(cat "$FIXTURES/heredoc-then-push.txt")"
assert_allows 'a push only named inside a heredoc body is allowed' \
  "$(cat "$FIXTURES/heredoc-body-mentions-push.txt")"
