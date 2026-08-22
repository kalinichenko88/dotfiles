#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/no-brew-bin"

DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" tools > "$tmp/tools.out"

for value in \
  'v0.40.3' \
  'nvm install v24.18.0' \
  'nvm alias default v24.18.0'; do
  assert_file_contains "$tmp/tools.out" "$value"
done

assert_file_excludes "$tmp/tools.out" 'v20.20.0'
assert_file_excludes "$tmp/tools.out" 'v22.23.1'
assert_file_excludes "$tmp/tools.out" '.bun'
assert_file_excludes "$tmp/tools.out" 'ohmyzsh'
[ ! -e "$tmp/home/.nvm" ] || fail 'tools dry run mutated the target home'

DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" all > "$tmp/all.out"
assert_file_contains "$tmp/all.out" 'scripts/doctor.sh'
assert_file_contains "$tmp/all.out" 'bootstrap-complete'
[ ! -e "$tmp/home/.config/dotfiles/bootstrap-complete" ] || \
  fail 'all dry run created the target completion marker'

if DOTFILES_HOMEBREW_BIN="$tmp/no-brew-bin/brew" \
  PATH="$tmp/no-brew-bin:/usr/bin:/bin" DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" brew > "$tmp/brew.out" 2> "$tmp/brew.err"; then
  fail 'missing Homebrew must require explicit authorization'
fi
assert_file_contains "$tmp/brew.err" 'INSTALL_HOMEBREW=1'

DRY_RUN=1 INSTALL_HOMEBREW=1 \
  DOTFILES_HOMEBREW_BIN="$tmp/no-brew-bin/brew" \
  PATH="$tmp/no-brew-bin:/usr/bin:/bin" \
  DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" brew > "$tmp/brew-dry.out"
assert_file_contains "$tmp/brew-dry.out" 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
assert_file_contains "$tmp/brew-dry.out" "$tmp/no-brew-bin/brew bundle install --file"
[ ! -e "$tmp/home/.homebrew-installed" ] || fail 'brew dry run mutated the target home'

# Homebrew will not load a formula or cask from an untrusted third-party tap,
# and `brew bundle` aborts on the first one. Every tap the Brewfile declares
# has to be trusted before the bundle runs, or a new machine cannot finish.
while IFS= read -r tap; do
  [ -n "$tap" ] || continue
  assert_file_contains "$tmp/brew-dry.out" "trust --tap $tap"
done < <(sed -n -E 's/^tap "([^"]+)".*/\1/p' "$TEST_ROOT/Brewfile")

if DRY_RUN=1 DOTFILES_HOMEBREW_BIN="$TEST_ROOT/tests/fixtures/bin/brew" \
  BREW_STUB_PREFIX=/usr/local PATH="$TEST_ROOT/tests/fixtures/bin:/usr/bin:/bin" \
  DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" brew > "$tmp/intel.out" 2> "$tmp/intel.err"; then
  fail 'bootstrap must reject an Intel Homebrew prefix on Apple Silicon'
fi
assert_file_contains "$tmp/intel.err" 'expected /opt/homebrew'

mkdir -p "$tmp/wrong-origin-home/.nvm"
git -C "$tmp/wrong-origin-home/.nvm" init -q
git -C "$tmp/wrong-origin-home/.nvm" remote add origin \
  https://example.invalid/not-nvm.git
if DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/wrong-origin-home" \
  "$TEST_ROOT/scripts/bootstrap.sh" tools \
  > "$tmp/origin.out" 2> "$tmp/origin.err"; then
  fail 'bootstrap must reject a checkout with an unexpected origin'
fi
assert_file_contains "$tmp/origin.err" 'unexpected origin'

# Cleanup uninstalls, so it reads the shared baseline and this machine's own
# manifest together — pointed at the tracked Brewfile alone it would remove
# everything Brewfile.local declares — and it does not pass --force unasked.
cleanup_env() {
  DRY_RUN=1 DOTFILES_HOMEBREW_BIN="$TEST_ROOT/tests/fixtures/bin/brew" \
    DOTFILES_TARGET_HOME="$tmp/home" "$@"
}

cleanup_env "$TEST_ROOT/scripts/bootstrap.sh" cleanup > "$tmp/cleanup.out"
assert_file_contains "$tmp/cleanup.out" 'bundle cleanup --file'
assert_file_excludes "$tmp/cleanup.out" '--force'

FORCE=1 cleanup_env "$TEST_ROOT/scripts/bootstrap.sh" cleanup \
  > "$tmp/cleanup-force.out"
assert_file_contains "$tmp/cleanup-force.out" 'bundle cleanup --force --file'

# An empty manifest must stop the run, not uninstall the whole machine.
mkdir -p "$tmp/empty-root"
: > "$tmp/empty-root/Brewfile"
if DOTFILES_ROOT="$tmp/empty-root" cleanup_env \
  "$TEST_ROOT/scripts/bootstrap.sh" cleanup \
  > "$tmp/cleanup-empty.out" 2> "$tmp/cleanup-empty.err"; then
  fail 'cleanup must refuse an empty manifest'
fi
assert_file_contains "$tmp/cleanup-empty.err" 'declares nothing'

pass 'bootstrap layers enforce pins, dry run, and the Homebrew boundary'
