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
# $2 pins the session, for the assertions that need a sequence of calls to share
# one; without it every call gets its own and cleans up after itself.
run_hook() {
  local session=${2:-dotfiles-hooks-test-$$-$RANDOM}
  jq -n --arg c "$1" --arg s "$session" --arg cwd "$tmp/repo" \
    '{tool_input: {command: $c}, session_id: $s, cwd: $cwd}' | bash "$HOOK"
  [ -n "${2:-}" ] || rm -f "/tmp/claude-docs-checked-$session-"*
}

# The hook denies with a JSON payload and allows by saying nothing.
assert_decision() {
  local decision
  case $(run_hook "$2" "${3:-}") in
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

# A deny arms only the command that earned it. The other recorded payload writes
# a document that names a push without running one: it is stopped, being text the
# hook cannot tell from a command, but the review the next real push owes must
# still be owed. Only a re-run of the same command passes.
session="dotfiles-hooks-sequence-$$-$RANDOM"
assert_decision deny "$(cat "$FIXTURES/heredoc-body-mentions-push.txt")" "$session"
assert_decision deny 'git push origin main' "$session"
assert_decision allow 'git push origin main' "$session"
rm -f "/tmp/claude-docs-checked-$session-"*

pass 'the docs hook stops a push wherever the command puts it'
