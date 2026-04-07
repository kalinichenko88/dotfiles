#!/usr/bin/env bash
#
# Sync kitty theme with current macOS appearance.
#
# Reads `defaults read -g AppleInterfaceStyle` (returns "Dark" in dark mode,
# errors out in light mode), then atomically swaps the
# kitty/themes/current-theme.conf symlink to point at dark.conf or light.conf,
# and finally calls `kitty @ load-config` to live-reload any running kitty
# instances.
#
# Safe to run when kitty is not yet installed or no kitty windows exist —
# the load-config call is best-effort and failure is non-fatal.

set -eu

# Resolve the directory containing this script, even when called via symlink.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
THEMES_DIR="$SCRIPT_DIR/themes"

if [ ! -d "$THEMES_DIR" ]; then
  echo "theme-sync: themes directory not found at $THEMES_DIR" >&2
  exit 1
fi

# Detect macOS appearance. The defaults command exits non-zero in light mode,
# so we tolerate the error and treat absence of the key as "light".
if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
  TARGET="dark.conf"
else
  TARGET="light.conf"
fi

# Atomic symlink swap: ln -sfn replaces the existing symlink in place.
ln -sfn "$TARGET" "$THEMES_DIR/current-theme.conf"

# Best-effort live reload of any running kitty instances. Failure is fine —
# kitty might not be installed yet, remote control might be disabled, or no
# windows might be open.
if command -v kitty >/dev/null 2>&1; then
  kitty @ load-config >/dev/null 2>&1 || true
fi
