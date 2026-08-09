# zsh trampoline: ZDOTDIR redirects per-user files here, so we load the real ones.
# ZDOTDIR currently points at our bundle (set by bootstrap.sh). Load the user's real
# ~/.zshenv — which may itself repoint ZDOTDIR (e.g. at ~/.config/zsh) — then take
# ZDOTDIR back so zsh keeps reading OUR .zprofile/.zshrc/.zlogin, where the remote
# prompt + nvim aliases live. Record the user's real zsh dir so the other trampolines
# source the user's real files from wherever the user keeps them.
_dfr_own_zdotdir="$ZDOTDIR"
[[ -r "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
if [[ "$ZDOTDIR" == "$_dfr_own_zdotdir" ]]; then
  export _DFR_USER_ZDOTDIR="$HOME"
else
  export _DFR_USER_ZDOTDIR="$ZDOTDIR"
fi
export ZDOTDIR="$_dfr_own_zdotdir"
unset _dfr_own_zdotdir
