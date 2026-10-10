#!/bin/bash
# Hook: check-docs-before-push
# PreToolUse hook that blocks git push and asks Claude to review
# documentation files (CLAUDE.md, README.md) before pushing.
#
# Uses a temp flag file keyed by session ID:
# - First push attempt: blocked with doc review reminder
# - Next push (after review), however it is worded: allowed, flag consumed

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Heredoc bodies are text, not commands: a document that starts a line with
# "git push" must neither be stopped nor spend the review the real push owes.
# The line after the terminator is a command again, and is kept.
HEREDOC_RE=$'(^|[^<])<<-?[[:space:]]*[\'"]?([[:alpha:]_][[:alnum:]_]*)'
strip_heredocs() {
  local line delim=
  while IFS= read -r line; do
    if [ -n "$delim" ]; then
      [ "${line#"${line%%[!$'\t']*}"}" = "$delim" ] && delim=
      continue
    fi
    printf '%s\n' "$line"
    [[ $line =~ $HEREDOC_RE ]] && delim=${BASH_REMATCH[2]}
  done <<< "$1"
}

# Match git push at a command boundary — "git commit && git push" is the common
# form, and a heredoc terminator ends the line, so a push written after one
# starts its own. Bash =~ has no multiline mode, hence the newline in the class.
PUSH_RE=$'(^|[;&|\n])[[:space:]]*git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push([[:space:]]|$)'
[[ $(strip_heredocs "$COMMAND") =~ $PUSH_RE ]] || exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# No session ID — can't track state, allow gracefully
[ -z "$SESSION_ID" ] && exit 0

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Keyed by the session alone: a retry rarely repeats the denied text — it pipes
# through another tail, or commits the README the review just fixed.
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

# Create flag so the next push in this session passes through
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
