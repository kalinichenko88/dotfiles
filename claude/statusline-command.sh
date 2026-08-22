#!/bin/bash
# Status line: "<model> (git: <branch>*) [context: <n>% used]"
# Claude Code feeds the session JSON on stdin and renders whatever this prints.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# This runs on every render, so skip the index refresh and the commit-graph.
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fileMode=false -c core.commitGraph=false \
    symbolic-ref --short HEAD 2>/dev/null || echo "detached")

  if ! git -C "$cwd" -c core.fileMode=false diff --quiet 2>/dev/null || \
     ! git -C "$cwd" -c core.fileMode=false diff --cached --quiet 2>/dev/null; then
    status="*"
  else
    status=""
  fi

  git_info=" (git: $branch$status)"
fi

context_info=""
if [ -n "$used_pct" ]; then
  context_info=" [context: ${used_pct}% used]"
fi

printf "%s%s%s" "$model" "$git_info" "$context_info"
