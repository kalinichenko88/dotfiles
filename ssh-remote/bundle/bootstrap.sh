#!/bin/sh
# Remote entrypoint (run as: sh ~/.dotfiles-remote/bundle/bootstrap.sh).
# Sets isolated XDG for nvim, picks nvim/vim/vi, exports DFR_NVIM + DOTFILES_REMOTE,
# then execs the user's interactive shell wired to our trampolines. Falls back to a
# plain shell on any problem so the user is never locked out.

DFR="$HOME/.dotfiles-remote"
export DOTFILES_REMOTE="$DFR/bundle"
export DOTFILES_REMOTE_BOOTSTRAPPED=1   # session marker only (NOT an override gate)

# Isolated XDG: config from the synced bundle; writable state in $DFR/state so
# `rsync --delete` on bundle/ can never wipe it.
_cfg="$DOTFILES_REMOTE/xdg/config"
_st="$DFR/state"
mkdir -p "$_st/data" "$_st/state" "$_st/cache" 2>/dev/null \
  || printf 'ssh-remote: warning: could not create state dirs under %s — nvim state will not persist\n' "$_st" >&2

# nvim: system > cached/downloaded (pinned, checksum-verified) > vim > vi.
# shellcheck source=/dev/null
[ -r "$DOTFILES_REMOTE/shell/nvim-install.sh" ] && . "$DOTFILES_REMOTE/shell/nvim-install.sh"
_nvim_bin=""
command -v _dfr_resolve_nvim >/dev/null 2>&1 && _nvim_bin="$(_dfr_resolve_nvim)"

if [ -n "$_nvim_bin" ]; then
  DFR_NVIM="env XDG_CONFIG_HOME='$_cfg' XDG_DATA_HOME='$_st/data' XDG_STATE_HOME='$_st/state' XDG_CACHE_HOME='$_st/cache' '$_nvim_bin'"
elif command -v vim >/dev/null 2>&1; then
  DFR_NVIM="vim"; printf 'ssh-remote: nvim unavailable, using vim\n' >&2
else
  DFR_NVIM="vi";  printf 'ssh-remote: nvim/vim unavailable, using vi\n' >&2
fi
export DFR_NVIM

_sh="${SHELL:-/bin/sh}"
case "${_sh##*/}" in
  zsh)  exec env ZDOTDIR="$DOTFILES_REMOTE/zdotdir" "$_sh" -l -i ;;
  bash) exec "$_sh" --init-file "$DOTFILES_REMOTE/bashrc" -i ;;
  *)    exec "$_sh" -i ;;
esac

# Only reached if exec failed.
exec "$_sh" -i
