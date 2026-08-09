#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"
export DOTFILES_HOMEBREW_BIN="$TEST_ROOT/tests/fixtures/bin/brew"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-inventory-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/tmp" "$tmp/home/.nvm/versions/node/v24.18.0" \
  "$tmp/home/.nvm/versions/node/v20.0.0"

before=$(shasum -a 256 "$TEST_ROOT/Brewfile" | awk '{print $1}')
BREW_STUB_SNAPSHOT='tap "stripe/stripe-cli", trusted: true
brew "fd"
brew "colima", restart_service: :changed
brew "source-only-tool"
cask "codex"
cask "umputun/apps/agterm", trusted: true
cask "source-only-app"' \
  PATH="$TEST_ROOT/tests/fixtures/bin:/usr/bin:/bin" \
  TMPDIR="$tmp/tmp" DOTFILES_TARGET_HOME="$tmp/home" \
  "$TEST_ROOT/scripts/inventory.sh" compare > "$tmp/output"
after=$(shasum -a 256 "$TEST_ROOT/Brewfile" | awk '{print $1}')

assert_equals "$before" "$after"
assert_file_contains "$tmp/output" 'manifest-only'
assert_file_contains "$tmp/output" 'source-only'
assert_file_contains "$tmp/output" 'brew "bun"'
assert_file_contains "$tmp/output" 'brew "source-only-tool"'
assert_file_contains "$tmp/output" 'cask "source-only-app"'
assert_file_excludes "$tmp/output" 'tap "stripe/stripe-cli", trusted: true'
assert_file_excludes "$tmp/output" 'brew "colima", restart_service: :changed'
assert_file_excludes "$tmp/output" 'cask "agterm"'
assert_file_excludes "$tmp/output" 'cask "umputun/apps/agterm"'
# Only drift is reported: the pinned version matches, the stray one does not.
assert_file_contains "$tmp/output" 'node-source-only	v20.0.0'
assert_file_excludes "$tmp/output" 'v24.18.0'

[ -z "$(find "$tmp/tmp" -mindepth 1 -print -quit)" ] || \
  fail 'inventory temporary snapshot was not removed'

pass 'inventory compares desired and actual state without mutation'
