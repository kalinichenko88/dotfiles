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

# Private scratch directory plus its cleanup. An unset DOTFILES_TMP makes the
# removal a no-op on its own, so the trap needs no further guarding.
dotfiles_make_tmp() {
  local base
  base=${TMPDIR:-/tmp}
  DOTFILES_TMP=$(mktemp -d "${base%/}/$1.XXXXXX") || return 1
}

dotfiles_cleanup_tmp() {
  [ -n "${DOTFILES_TMP:-}" ] && /bin/rm -rf "$DOTFILES_TMP"
  DOTFILES_TMP=
}

# Streams a tracked manifest followed by its optional gitignored machine-local
# sibling, so machine-specific software never lands in the shared baseline.
# awk rather than cat: it terminates the last line of each file, so a tracked
# manifest that lost its trailing newline cannot glue its final entry onto the
# local file's first one and drop both.
dotfiles_manifest() {
  if [ -f "$DOTFILES_ROOT/$2" ]; then
    awk 1 "$DOTFILES_ROOT/$1" "$DOTFILES_ROOT/$2"
  else
    awk 1 "$DOTFILES_ROOT/$1"
  fi
}

# Streams `label<TAB>source<TAB>target` for the symlinked configuration, for one
# unit or, with no argument, all of them. bootstrap installs from this table and
# doctor verifies from it, so the two can no longer drift apart.
dotfiles_links() {
  awk -F '\t' -v unit="${1:-}" '
    NF && $1 !~ /^#/ && (unit == "" || $1 == unit) { print $2 "\t" $3 "\t" $4 }
  ' "$DOTFILES_ROOT/setup/links.tsv"
}

# Emits `kind<TAB>token` for every tap/brew/cask record on stdin or in the named
# files. Trusting taps, doctor and inventory each want something different out
# of a Brewfile, but all three were parsing it themselves; only the parse is
# shared here.
dotfiles_brewfile_records() {
  awk '
    match($0, /^(tap|brew|cask)[[:space:]]+"[^"]+"/) {
      record = substr($0, RSTART, RLENGTH)
      kind = record
      sub(/[[:space:]].*$/, "", kind)
      split(record, parts, "\"")
      print kind "\t" parts[2]
    }
  ' "$@"
}

# macOS ships no timeout(1). Callers only care whether the probe succeeded, so
# a killed command reporting failure is all the resolution needed.
dotfiles_run_with_timeout() {
  local timeout_seconds command_pid timer_pid command_status
  timeout_seconds=$1
  shift

  "$@" &
  command_pid=$!
  (sleep "$timeout_seconds"; kill -KILL "$command_pid" 2>/dev/null) \
    </dev/null >/dev/null 2>&1 &
  timer_pid=$!

  wait "$command_pid" && command_status=0 || command_status=$?
  kill "$timer_pid" 2>/dev/null || :
  wait "$timer_pid" 2>/dev/null || :
  return "$command_status"
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

# Merges tracked JSON into a target that other tools also write to, so their
# keys survive. The jq program gets the target as input and the tracked file as
# $source; a missing target is treated as {}. No FORCE is needed, because
# nothing outside the tracked keys is replaced.
dotfiles_merge_json() {
  local relative_source target program source_path target_dir temp_file
  relative_source=$1
  target=$2
  # $source is a jq variable, not a shell one.
  # shellcheck disable=SC2016
  program=${3:-'. * $source[0]'}
  source_path=$DOTFILES_ROOT/$relative_source
  target_dir=$(dirname -- "$target")

  if [ ! -f "$source_path" ]; then
    dotfiles_die "merge source is not a file: $source_path"
    return 1
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    dotfiles_info "would merge $relative_source into $target"
    return 0
  fi

  mkdir -p "$target_dir"
  if ! temp_file=$(mktemp "$target_dir/.dotfiles-merge.XXXXXX"); then
    dotfiles_die "could not create a temporary file next to $target"
    return 1
  fi

  if ! { [ -f "$target" ] && cat "$target" || printf '{}\n'; } \
    | jq --slurpfile source "$source_path" "$program" > "$temp_file"; then
    rm -f "$temp_file"
    dotfiles_die "could not merge $relative_source into $target"
    return 1
  fi
  chmod 600 "$temp_file"

  if [ -f "$target" ] && cmp -s "$target" "$temp_file"; then
    rm -f "$temp_file"
    dotfiles_info "merge already applied: $target"
    return 0
  fi
  if [ -f "$target" ] && ! dotfiles_backup_target "$target"; then
    rm -f "$temp_file"
    return 1
  fi

  mv "$temp_file" "$target"
  dotfiles_info "merged $relative_source into $target"
}
