#!/bin/bash

set -eu

unset CDPATH
TEST_ROOT=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
export TEST_ROOT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$*"
}

assert_file_contains() {
  grep -F -- "$2" "$1" >/dev/null 2>&1 || fail "$1 lacks $2"
}

assert_file_excludes() {
  if grep -F -- "$2" "$1" >/dev/null 2>&1; then
    fail "$1 contains $2"
  fi
}

assert_equals() {
  [ "$1" = "$2" ] || fail "expected [$1], got [$2]"
}
