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

# The hook denies with a JSON payload and allows by saying nothing.
assert_decision() {
  local decision
  case $(run_hook "$2") in
    '') decision=allow ;;
    *) decision=deny ;;
  esac
  assert_equals "$1" "$decision"
}

assert_decision deny 'git push'
assert_decision deny 'git commit -m x && git push'
assert_decision deny "$(printf 'cd /repo\ngit push origin main')"
assert_decision allow 'git status'

# A recorded payload: the heredoc terminator ends the line, so a commit message
# written through one always leaves the push on a line of its own.
assert_decision deny "$(cat "$FIXTURES/heredoc-then-push.txt")"

pass 'the docs hook stops a push wherever the command puts it'
