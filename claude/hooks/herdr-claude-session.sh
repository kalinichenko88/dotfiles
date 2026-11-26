#!/bin/bash
# Hook: herdr-claude-session
# SessionStart hook for zsh/herdr.zsh. It writes the conversation's id to the
# file that the claude wrapper names in CLAUDE_HERDR_SESSION_FILE, so the next
# shell in a lost Herdr terminal resumes that conversation.
#
# A claude that a tool starts inside the conversation inherits the variable
# and starts as "startup". The wrapper removes the file before its own start,
# so only the first start, /clear, /resume and a compaction write it.
# Nothing goes to stdout: SessionStart adds stdout to the conversation.

[ -n "${CLAUDE_HERDR_SESSION_FILE:-}" ] || exit 0
INPUT=$(cat)
SOURCE=$(jq -r '.source // empty' <<< "$INPUT" 2>/dev/null)
[ "$SOURCE" = startup ] && [ -e "$CLAUDE_HERDR_SESSION_FILE" ] && exit 0
jq -r '.session_id // empty' <<< "$INPUT" > "$CLAUDE_HERDR_SESSION_FILE" 2>/dev/null
exit 0
