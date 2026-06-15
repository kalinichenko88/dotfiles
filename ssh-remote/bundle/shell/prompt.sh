# Remote prompt (bash/sh): bright red "remote" segment + host + cwd.
# Sourced by the bash trampoline after the user's profile.
# Glyph needs bash >= 4.2 ($'\uXXXX'); fall back to an ASCII marker otherwise.
_dfr_glyph='[ssh]'
if [ -n "${BASH_VERSINFO:-}" ] && { [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ]; }; }; then
  _dfr_glyph=$''
fi
PS1="\[\e[41;97m\] ${_dfr_glyph} \h \[\e[0m\] \[\e[36m\]\w\[\e[0m\] \$ "
unset _dfr_glyph
