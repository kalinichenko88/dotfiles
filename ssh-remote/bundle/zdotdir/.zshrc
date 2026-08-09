# Load the user's real interactive config first… (from their ZDOTDIR if they set one,
# captured as _DFR_USER_ZDOTDIR by our .zshenv; else $HOME).
[[ -r "${_DFR_USER_ZDOTDIR:-$HOME}/.zshrc" ]] && source "${_DFR_USER_ZDOTDIR:-$HOME}/.zshrc"

# …then our overrides, once per shell (guard is shell-local, NOT exported, so a
# child interactive shell re-applies the remote prompt/aliases). The ${...:-}
# default keeps this safe under a user's `setopt nounset`.
if [[ -z "${_DFR_ZSHRC_DONE:-}" ]]; then
  typeset -g _DFR_ZSHRC_DONE=1
  [[ -r "$DOTFILES_REMOTE/shell/prompt.zsh" ]] && source "$DOTFILES_REMOTE/shell/prompt.zsh"
  if [[ -n "${DFR_NVIM:-}" ]]; then
    alias v="$DFR_NVIM" vim="$DFR_NVIM" vi="$DFR_NVIM"
    export EDITOR="$DFR_NVIM"
  fi
fi
