# Remote prompt (zsh): bright red "remote" segment + short host + cwd.
# Sourced by the zsh trampoline after the user's real ~/.zshrc.
setopt prompt_subst
#   = nerd-font server glyph; renders via the LOCAL terminal font.
PROMPT='%K{red}%F{white} '$''' %m %f%k %F{cyan}%~%f %# '
