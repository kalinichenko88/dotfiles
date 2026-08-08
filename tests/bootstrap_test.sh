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
  '0912e05c0589d26ea20d79555487900880aad4d5' \
  'v0.40.3' \
  'nvm install v24.18.0' \
  'nvm alias default v24.18.0' \
  'uv tool install --force mcp-telegram==0.1.2' \
  'uv tool install --force specify-cli==0.8.4'; do
  assert_file_contains "$tmp/tools.out" "$value"
done
assert_file_excludes "$tmp/tools.out" 'v20.20.0'
assert_file_excludes "$tmp/tools.out" 'v22.23.1'
assert_file_excludes "$tmp/tools.out" '.bun'
[ ! -e "$tmp/home/.nvm" ] || fail 'tools dry run mutated the target home'

DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" all > "$tmp/all.out"
assert_file_contains "$tmp/all.out" 'DOTFILES_STRICT_BREW=1'
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

if DRY_RUN=1 DOTFILES_HOMEBREW_BIN="$TEST_ROOT/tests/fixtures/bin/brew" \
  BREW_STUB_PREFIX=/usr/local PATH="$TEST_ROOT/tests/fixtures/bin:/usr/bin:/bin" \
  DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/bootstrap.sh" brew > "$tmp/intel.out" 2> "$tmp/intel.err"; then
  fail 'bootstrap must reject an Intel Homebrew prefix on Apple Silicon'
fi
assert_file_contains "$tmp/intel.err" 'expected /opt/homebrew'

mkdir -p "$tmp/wrong-origin-home/.oh-my-zsh"
git -C "$tmp/wrong-origin-home/.oh-my-zsh" init -q
git -C "$tmp/wrong-origin-home/.oh-my-zsh" remote add origin \
  https://example.invalid/not-ohmyzsh.git
if DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/wrong-origin-home" \
  "$TEST_ROOT/scripts/bootstrap.sh" tools \
  > "$tmp/origin.out" 2> "$tmp/origin.err"; then
  fail 'bootstrap must reject a checkout with an unexpected origin'
fi
assert_file_contains "$tmp/origin.err" 'unexpected origin'

pass 'bootstrap layers enforce pins, dry run, and the Homebrew boundary'
