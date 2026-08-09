# zsh -l reads .zlogin after .zshrc; preserve the user's (from their ZDOTDIR if set).
[[ -r "${_DFR_USER_ZDOTDIR:-$HOME}/.zlogin" ]] && source "${_DFR_USER_ZDOTDIR:-$HOME}/.zlogin"
