#!/bin/bash

set -u

unset CDPATH

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fi
DOTFILES_TARGET_HOME=${DOTFILES_TARGET_HOME:-$HOME}
DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}
export DOTFILES_ROOT DOTFILES_TARGET_HOME DRY_RUN FORCE

dotfiles_info() {
  printf 'info: %s\n' "$*"
}

dotfiles_warn() {
  printf 'warning: %s\n' "$*" >&2
}

dotfiles_die() {
  printf 'error: %s\n' "$*" >&2
  return 1
}

# Streams a tracked manifest followed by its optional gitignored machine-local
# sibling, so machine-specific software never lands in the shared baseline.
dotfiles_manifest() {
  cat "$DOTFILES_ROOT/$1"
  [ -f "$DOTFILES_ROOT/$2" ] && cat "$DOTFILES_ROOT/$2"
  return 0
}

dotfiles_uv_tool_specs() {
  uv tool list 2>/dev/null | awk '/^[^[:space:]]+[[:space:]]+v?[0-9]/ {
    version=$2
    sub(/^v/, "", version)
    print $1 "==" version
  }' | sort -u
}

dotfiles_resolve_homebrew() {
  local brew_command expected_prefix actual_prefix
  brew_command=${DOTFILES_HOMEBREW_BIN:-/opt/homebrew/bin/brew}
  expected_prefix=${DOTFILES_HOMEBREW_PREFIX:-/opt/homebrew}

  if [ ! -x "$brew_command" ]; then
    dotfiles_die "Apple Silicon Homebrew is unavailable at $brew_command"
    return 1
  fi
  if ! actual_prefix=$("$brew_command" --prefix 2>/dev/null); then
    dotfiles_die 'could not determine the Homebrew prefix'
    return 1
  fi
  if [ "$actual_prefix" != "$expected_prefix" ]; then
    dotfiles_die "Homebrew prefix is $actual_prefix; expected $expected_prefix on Apple Silicon"
    return 1
  fi
  DOTFILES_BREW_COMMAND=$brew_command
  export DOTFILES_BREW_COMMAND
}

dotfiles_print_command() {
  printf '+'
  while [ "$#" -gt 0 ]; do
    printf ' %q' "$1"
    shift
  done
  printf '\n'
}

dotfiles_run() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    dotfiles_print_command "$@"
    return 0
  fi

  "$@"
}

dotfiles_path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

dotfiles_backup_target() {
  local target timestamp backup
  target=$1
  timestamp=$(date '+%Y%m%d-%H%M%S')
  backup=${target}.backup.${timestamp}

  if dotfiles_path_exists "$backup"; then
    backup=${backup}.$$
  fi
  if dotfiles_path_exists "$backup"; then
    dotfiles_die "backup path already exists: $backup"
    return 1
  fi

  dotfiles_info "backing up $target to $backup"
  dotfiles_run mv "$target" "$backup"
}

dotfiles_prepare_parent() {
  local parent
  parent=$(dirname -- "$1")
  if [ ! -d "$parent" ]; then
    dotfiles_run mkdir -p "$parent"
  fi
}

dotfiles_link() {
  local relative_source target source_path
  relative_source=$1
  target=$2
  source_path=$DOTFILES_ROOT/$relative_source

  if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    dotfiles_die "link source does not exist: $source_path"
    return 1
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source_path" ]; then
    dotfiles_info "link already installed: $target"
    return 0
  fi

  if dotfiles_path_exists "$target"; then
    if [ "${FORCE:-0}" != 1 ]; then
      dotfiles_die "target exists; rerun with FORCE=1 to back it up: $target"
      return 1
    fi
    dotfiles_backup_target "$target" || return 1
  fi

  dotfiles_prepare_parent "$target"
  dotfiles_run ln -s "$source_path" "$target"
  dotfiles_info "linked $target"
}

dotfiles_copy() {
  local relative_source target source_path
  relative_source=$1
  target=$2
  source_path=$DOTFILES_ROOT/$relative_source

  if [ ! -f "$source_path" ]; then
    dotfiles_die "copy source is not a file: $source_path"
    return 1
  fi

  if [ -f "$target" ] && cmp -s "$source_path" "$target"; then
    dotfiles_info "copy already installed: $target"
    return 0
  fi

  if dotfiles_path_exists "$target"; then
    if [ "${FORCE:-0}" != 1 ]; then
      dotfiles_die "target exists; rerun with FORCE=1 to back it up: $target"
      return 1
    fi
    dotfiles_backup_target "$target" || return 1
  fi

  dotfiles_prepare_parent "$target"
  dotfiles_run cp "$source_path" "$target"
  dotfiles_info "copied $target"
}
