# Claude Code resume for Herdr. A lost Herdr terminal (a reboot, a core crash)
# gets a bare shell with the same HC_TERMINAL_ID, and Herdr never runs its
# program again. So while claude runs, a mark keeps its folder and arguments,
# and claude/hooks/herdr-claude-session.sh adds the conversation's id. Claude
# ending in any way removes the mark; a lost terminal keeps it, and the next
# shell there resumes the conversation at its first prompt.
#
# Outside Herdr, and in the shells Claude Code starts, the file stops here and
# claude stays the agterm wrapper of claude-resume.zsh.
[[ $HC_TERMINAL_ID =~ '^[a-z0-9]+$' && -z $CLAUDECODE ]] || return 0

_claude_herdr_mark=${XDG_STATE_HOME:-$HOME/.local/state}/claude-herdr/$HC_TERMINAL_ID

# ponytail: a pane closed while claude runs leaves its mark behind; Herdr does
# not reuse addresses, so it is never read. Prune by `hc ls` if they pile up.
claude() {
  mkdir -p "${_claude_herdr_mark:h}" &&
    print -rl -- "$PWD" "${(j: :)${(q)@}}" > "$_claude_herdr_mark"
  rm -f "$_claude_herdr_mark.session"
  _claude_herdr_run "$@"
}

_claude_herdr_run() {
  {
    CLAUDE_HERDR_SESSION_FILE=$_claude_herdr_mark.session command claude "$@"
  } always {
    rm -f "$_claude_herdr_mark" "$_claude_herdr_mark.session"
  }
}

_claude_herdr_resume() {
  precmd_functions=(${precmd_functions:#_claude_herdr_resume})
  [[ -s $_claude_herdr_mark.session ]] || return 0
  local -a mark=("${(@f)$(<"$_claude_herdr_mark")}")
  local session=$(<"$_claude_herdr_mark.session")
  cd -- "$mark[1]" &&
    eval "_claude_herdr_run --resume ${(q)session} $mark[2]"
}
precmd_functions+=(_claude_herdr_resume)
