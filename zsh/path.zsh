typeset -U path PATH

# Homebrew on Apple Silicon. The fallback makes a newly installed brew visible.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
fi

# Homebrew's libpq is keg-only.
[[ -d /opt/homebrew/opt/libpq/bin ]] && path=(/opt/homebrew/opt/libpq/bin $path)

# So is imagemagick-full, the build that links librsvg and so renders SVG text.
[[ -d /opt/homebrew/opt/imagemagick-full/bin ]] && path=(/opt/homebrew/opt/imagemagick-full/bin $path)

# Homebrew's python formulae link only python3/pip3 into bin; the unversioned
# python and pip live in libexec. Globbed rather than pinned so a version bump
# in the Brewfile needs no edit here; numeric sort leaves the newest first.
for python_libexec in /opt/homebrew/opt/python@*/libexec/bin(Nn); do
  path=("$python_libexec" $path)
done
unset python_libexec

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
