#!/bin/bash
# Hook: check-docs-before-push
# PreToolUse hook that blocks git push and asks Claude to review
# documentation files (CLAUDE.md, README.md) before pushing.
#
# Uses a temp flag file keyed by session ID:
# - First push attempt: blocked with doc review reminder
# - Second attempt (after review): allowed, flag consumed

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Match git push at a command boundary — "git commit && git push" is the common form.
PUSH_RE='(^[[:space:]]*|[;&|][[:space:]]*)git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push([[:space:]]|$)'
[[ $COMMAND =~ $PUSH_RE ]] || exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# No session ID — can't track state, allow gracefully
[ -z "$SESSION_ID" ] && exit 0

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

CHECK_FILE="/tmp/claude-docs-checked-${SESSION_ID}"

# If already checked in this push cycle, allow and consume the flag
if [ -f "$CHECK_FILE" ]; then
  rm -f "$CHECK_FILE"
  exit 0
fi

# ls-files, not find: paths come back repo-relative and sorted, and .gitignore
# already excludes node_modules, dist, .venv and friends.
DOC_LIST=$(git -C "$REPO_ROOT" ls-files '*README.md' '*CLAUDE.md' | sed 's/^/  - /')
[ -z "$DOC_LIST" ] && exit 0

# Create flag so the next push attempt passes through
touch "$CHECK_FILE"

REASON="Review documentation before pushing. Check if these files need updating based on the commits you are about to push:
${DOC_LIST}
After reviewing (and updating if needed), re-run the push command."

jq -n --arg reason "$REASON" \
'{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
