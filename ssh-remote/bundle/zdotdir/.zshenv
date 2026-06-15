# zsh trampoline: ZDOTDIR redirects per-user files here, so we load the real ones.
[[ -r "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
