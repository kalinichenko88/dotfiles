#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

assert_make_target() {
  target=$1
  expected=$2
  output=$(make -s -n -C "$TEST_ROOT" "$target") || fail "make target failed: $target"
  printf '%s\n' "$output" | grep -F -- "$expected" >/dev/null || \
    fail "$target does not delegate to $expected"
}

assert_make_target bootstrap './scripts/bootstrap.sh all'
assert_make_target bootstrap-brew './scripts/bootstrap.sh brew'
assert_make_target bootstrap-tools './scripts/bootstrap.sh tools'
assert_make_target config-install './scripts/bootstrap.sh config'
assert_make_target update './scripts/bootstrap.sh update'
assert_make_target doctor './scripts/doctor.sh'
assert_make_target inventory './scripts/inventory.sh compare'

# Every unit installable on its own, and named after what it actually installs.
for unit in dev-dirs git zsh nvim wezterm gh starship docker claude; do
  assert_make_target "config-$unit" "./scripts/bootstrap.sh config $unit"
done

for removed_target in brew-dump cleanup-candidates security-audit; do
  if make -s -n -C "$TEST_ROOT" "$removed_target" >/dev/null 2>&1; then
    fail "$removed_target must not be part of the Make interface"
  fi
done

pass 'Make exposes only safe workstation entry points'
