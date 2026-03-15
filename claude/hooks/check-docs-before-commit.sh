#!/bin/bash
# Hook: check-docs-before-commit
# PreToolUse hook that blocks git commit and asks Claude to review
# documentation files (CLAUDE.md, README.md) before committing.
#
# Uses a temp flag file keyed by session ID:
# - First commit attempt: blocked with doc review reminder
# - Second attempt (after review): allowed, flag consumed

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+(-C\s+\S+\s+)?commit'; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# No session ID — can't track state, allow gracefully
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Find git repo root
REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

CHECK_FILE="/tmp/claude-docs-checked-${SESSION_ID}"

# If already checked in this commit cycle, allow and consume the flag
if [ -f "$CHECK_FILE" ]; then
  rm -f "$CHECK_FILE"
  exit 0
fi

# Find documentation files in the repo
DOC_FILES=$(find "$REPO_ROOT" -maxdepth 5 \
  \( -name "CLAUDE.md" -o -name "README.md" \) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.next/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.venv/*" \
  2>/dev/null | sort)

# No doc files found — nothing to check
if [ -z "$DOC_FILES" ]; then
  exit 0
fi

# Create flag so the next commit attempt passes through
touch "$CHECK_FILE"

# Format file list relative to repo root
DOC_LIST=$(echo "$DOC_FILES" | while read -r f; do echo "  - ${f#${REPO_ROOT}/}"; done)

REASON="Review documentation before committing. Check if these files need updating based on your staged changes:
${DOC_LIST}
After reviewing (and updating if needed), re-run the commit command."

jq -n --arg reason "$REASON" \
'{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
