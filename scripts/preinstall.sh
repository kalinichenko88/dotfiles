#!/bin/bash

# Everything that has to happen before `make bootstrap` can run at all, on a
# Mac with nothing installed. Safe to pipe from the network because the only
# things it does are install Apple's Command Line Tools and clone this public
# repository over HTTPS:
#
#   curl -fsSL https://raw.githubusercontent.com/kalinichenko88/dotfiles/main/scripts/preinstall.sh | bash
#
# Rerunning is harmless.

set -euo pipefail

REPOSITORY_URL=https://github.com/kalinichenko88/dotfiles.git
SSH_REMOTE_URL=git@github.com:kalinichenko88/dotfiles.git
DESTINATION=${DOTFILES_DESTINATION:-$HOME/Dev/Personal/dotfiles}

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  printf 'error: this setup supports Apple Silicon macOS only\n' >&2
  exit 1
fi

# Command Line Tools are what provide git. The installer is a GUI dialog, so
# this can only start it and ask for a rerun.
if ! xcode-select -p >/dev/null 2>&1; then
  printf 'Installing the Command Line Tools. Accept the dialog, wait for it to\n'
  printf 'finish, then run this script again.\n'
  xcode-select --install || :
  exit 1
fi

# HTTPS, not SSH: the SSH key lives in 1Password, which the bootstrap installs
# from a Brewfile inside this very repository. Cloning must not need it.
if [ -d "$DESTINATION/.git" ]; then
  printf 'Repository already present, updating: %s\n' "$DESTINATION"
  git -C "$DESTINATION" pull --ff-only
else
  mkdir -p "$(dirname -- "$DESTINATION")"
  git clone "$REPOSITORY_URL" "$DESTINATION"
fi

cat <<EOF

Ready. Next:

  cd "$DESTINATION"
  INSTALL_HOMEBREW=1 make bootstrap

Once that finishes, to push from this machine:

  1. open 1Password and sign in
  2. turn on Settings -> Developer -> SSH agent
  3. git -C "$DESTINATION" remote set-url origin $SSH_REMOTE_URL
EOF
