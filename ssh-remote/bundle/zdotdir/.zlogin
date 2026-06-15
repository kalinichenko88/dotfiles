# zsh -l reads .zlogin after .zshrc; preserve the user's.
[[ -r "$HOME/.zlogin" ]] && source "$HOME/.zlogin"
