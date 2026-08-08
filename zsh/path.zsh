typeset -U path PATH

# Homebrew on Apple Silicon. The fallback makes a newly installed brew visible.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
fi

# Homebrew's libpq is keg-only.
[[ -d /opt/homebrew/opt/libpq/bin ]] && path=(/opt/homebrew/opt/libpq/bin $path)

# User-space command-line tools.
path=("$HOME/.local/bin" $path)
export PNPM_HOME="$HOME/Library/pnpm"
path=("$PNPM_HOME" $path)

# NVM and the exact Node baseline are installed by scripts/bootstrap.sh.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# Optional application-bundled CLIs.
[[ -d "$HOME/.opencode/bin" ]] && path=("$HOME/.opencode/bin" $path)
[[ -d "$HOME/.lmstudio/bin" ]] && path=("$HOME/.lmstudio/bin" $path)
[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
