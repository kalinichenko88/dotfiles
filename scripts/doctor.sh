#!/bin/bash

set -euo pipefail

unset CDPATH
SCRIPT_DIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# The common library path is derived from this script at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

LC_ALL=C
export LC_ALL

DOCTOR_FAILURES=0
DOCTOR_APPLICATIONS_ROOT=${DOTFILES_APPLICATIONS_ROOT:-}
DOCTOR_AUTH_TIMEOUT_SECONDS=${DOCTOR_AUTH_TIMEOUT_SECONDS:-3}

trap dotfiles_cleanup_tmp EXIT
trap 'exit 130' HUP INT TERM

doctor_status() {
  printf '%s %s %s\n' "$1" "$2" "$3"
}

doctor_missing() {
  DOCTOR_FAILURES=$((DOCTOR_FAILURES + 1))
  doctor_status missing "$1" "$2"
}

# macOS ships no timeout(1). Callers only care whether the probe succeeded, so
# a killed command reporting failure is all the resolution needed.
run_with_timeout() {
  local timeout_seconds command_pid timer_pid command_status
  timeout_seconds=$1
  shift

  "$@" &
  command_pid=$!
  (sleep "$timeout_seconds"; kill -KILL "$command_pid" 2>/dev/null) &
  timer_pid=$!

  wait "$command_pid" && command_status=0 || command_status=$?
  kill "$timer_pid" 2>/dev/null || :
  wait "$timer_pid" 2>/dev/null || :
  return "$command_status"
}

brewfile_tokens() {
  local record_type
  record_type=$1
  dotfiles_manifest Brewfile Brewfile.local | awk -v record_type="$record_type" '
    match($0, "^" record_type " \\\"[^\\\"]+\\\"") {
      value=substr($0, RSTART + length(record_type) + 2,
        RLENGTH - length(record_type) - 3)
      print value
    }
  '
}

load_brew_state() {
  dotfiles_resolve_homebrew

  "$DOTFILES_BREW_COMMAND" tap | sort -u > "$doctor_tmp/taps"
  "$DOTFILES_BREW_COMMAND" list --formula | sort -u > "$doctor_tmp/formulae"
  "$DOTFILES_BREW_COMMAND" list --cask | sort -u > "$doctor_tmp/casks"
}

# Not merged with check_formulae: a tap is owner/name and keeps its prefix,
# while a formula from a tap is matched by basename.
check_taps() {
  local tap_name
  while IFS= read -r tap_name; do
    [ -n "$tap_name" ] || continue
    if grep -Fx "$tap_name" "$doctor_tmp/taps" >/dev/null 2>&1; then
      doctor_status present tap "$tap_name"
    else
      doctor_missing tap "$tap_name"
    fi
  done <<EOF
$(brewfile_tokens tap)
EOF
}

check_formulae() {
  local formula_name installed_name
  while IFS= read -r formula_name; do
    [ -n "$formula_name" ] || continue
    installed_name=${formula_name##*/}
    if grep -Fx "$installed_name" "$doctor_tmp/formulae" >/dev/null 2>&1; then
      doctor_status present formula "$installed_name"
    else
      doctor_missing formula "$installed_name"
    fi
  done <<EOF
$(brewfile_tokens brew)
EOF
}

cask_bundle_path() {
  dotfiles_manifest setup/cask-apps.tsv setup/cask-apps.local.tsv \
    | awk -F '\t' -v token="$1" '$1 == token { print $2; exit }'
}

check_casks() {
  local cask_name installed_name bundle_path effective_path
  while IFS= read -r cask_name; do
    [ -n "$cask_name" ] || continue
    installed_name=${cask_name##*/}
    if grep -Fx "$installed_name" "$doctor_tmp/casks" >/dev/null 2>&1; then
      doctor_status present cask "$installed_name"
      continue
    fi

    bundle_path=$(cask_bundle_path "$installed_name")
    if [ -n "$bundle_path" ]; then
      effective_path=$DOCTOR_APPLICATIONS_ROOT$bundle_path
      if [ -e "$effective_path" ]; then
        doctor_status present-manual cask "$installed_name"
        continue
      fi
    fi
    doctor_missing cask "$installed_name"
  done <<EOF
$(brewfile_tokens cask)
EOF
}

check_node() {
  local node_version default_alias expected_default node_path node_version_output
  expected_default=
  while IFS= read -r node_version; do
    case "$node_version" in
      ''|'#'*) continue ;;
    esac
    # There is one NVM default alias, so only the first pin can claim it.
    [ -n "$expected_default" ] || expected_default=$node_version
    node_path=$DOTFILES_TARGET_HOME/.nvm/versions/node/$node_version/bin/node
    node_version_output=$doctor_tmp/node-version.$RANDOM
    if [ -x "$node_path" ] && \
      run_with_timeout 5 \
        "$node_path" --version > "$node_version_output" 2>/dev/null && \
      cmp -s <(printf '%s\n' "$node_version") "$node_version_output"; then
      doctor_status present node "$node_version"
    else
      doctor_missing node "$node_version"
    fi
  done < "$DOTFILES_ROOT/setup/node-versions.txt"

  [ -n "$expected_default" ] || return 0
  default_alias=
  if [ -f "$DOTFILES_TARGET_HOME/.nvm/alias/default" ]; then
    default_alias=$(sed -n '1p' "$DOTFILES_TARGET_HOME/.nvm/alias/default")
  fi
  if [ "$default_alias" = "$expected_default" ]; then
    doctor_status present node-default "$expected_default"
  else
    doctor_missing node-default "$expected_default"
  fi
}

check_uv_tools() {
  local tool_spec
  : > "$doctor_tmp/uv-tools"
  if command -v uv >/dev/null 2>&1; then
    dotfiles_uv_tool_specs > "$doctor_tmp/uv-tools"
  fi

  while IFS= read -r tool_spec; do
    case "$tool_spec" in
      ''|'#'*) continue ;;
    esac
    if grep -Fx "$tool_spec" "$doctor_tmp/uv-tools" >/dev/null 2>&1; then
      doctor_status present uv-tool "$tool_spec"
    else
      doctor_missing uv-tool "$tool_spec"
    fi
  done < "$DOTFILES_ROOT/setup/uv-tools.txt"
}

check_link() {
  local relative_source target label expected_source
  relative_source=$1
  target=$2
  label=$3
  expected_source=$DOTFILES_ROOT/$relative_source

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$expected_source" ]; then
    doctor_status present config "$label"
  else
    doctor_missing config "$label"
  fi
}

check_config() {
  local item item_name
  check_link git/gitconfig "$DOTFILES_TARGET_HOME/.config/git/config" git
  check_link git/gitconfig-personal \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-personal" git-personal
  check_link zsh/zshrc "$DOTFILES_TARGET_HOME/.zshrc" zsh
  check_link nvim "$DOTFILES_TARGET_HOME/.config/nvim" nvim
  check_link wezterm.lua "$DOTFILES_TARGET_HOME/.wezterm.lua" wezterm
  check_link gh/config.yml "$DOTFILES_TARGET_HOME/.config/gh/config.yml" gh
  check_link starship/starship.toml \
    "$DOTFILES_TARGET_HOME/.config/starship.toml" starship

  # Containment, not equality: docker login adds registry credentials to the
  # same file, and the merge deliberately leaves them alone.
  if command -v jq >/dev/null 2>&1 && \
    jq -e --slurpfile source "$DOTFILES_ROOT/docker/config.json" \
      'contains($source[0])' \
      "$DOTFILES_TARGET_HOME/.docker/config.json" >/dev/null 2>&1; then
    doctor_status present config docker
  else
    doctor_missing config docker
  fi

  for item in "$DOTFILES_ROOT"/claude/skills/*; do
    [ -d "$item" ] || continue
    item_name=$(basename -- "$item")
    check_link "claude/skills/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/skills/$item_name" "claude-skill-$item_name"
  done
  for item in "$DOTFILES_ROOT"/claude/hooks/*.sh; do
    [ -f "$item" ] || continue
    item_name=$(basename -- "$item")
    check_link "claude/hooks/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/hooks/$item_name" "claude-hook-$item_name"
  done

  if [ -f "$DOTFILES_TARGET_HOME/.config/git/gitconfig-work" ] && \
    [ -f "$DOTFILES_TARGET_HOME/.config/git/gitconfig-local" ]; then
    doctor_status present config git-local-templates
  else
    doctor_missing config git-local-templates
  fi

  # An untouched template satisfies useConfigOnly, so Git would happily author
  # work commits as the placeholder instead of refusing.
  if grep -Fq 'your-work-email@company.com' \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-work" 2>/dev/null; then
    doctor_missing config git-work-email
  else
    doctor_status present config git-work-email
  fi

  # Containment, not equality: the merge preserves hooks this repository does
  # not declare, and demanding equality would delete them to stay green.
  if command -v jq >/dev/null 2>&1 && \
    jq -e --slurpfile hooks "$DOTFILES_ROOT/claude/hooks-config.json" \
      '.hooks | contains($hooks[0])' \
      "$DOTFILES_TARGET_HOME/.claude/settings.json" \
      >/dev/null 2>&1; then
    doctor_status present config claude-settings
  else
    doctor_missing config claude-settings
  fi
}

check_manual_state() {
  local kind name probe probe_command effective_path
  while IFS=$'\t' read -r kind name probe || [ -n "${kind:-}" ]; do
    case "$kind" in
      command)
        probe_command=${probe%% *}
        # Not installed yet is a warning: these ship their own installers and
        # bootstrap only prints the checklist. Installed but broken is a failure.
        if ! command -v "$probe_command" >/dev/null 2>&1; then
          doctor_status warning manual-command "$name"
        elif run_with_timeout 5 \
          /bin/bash -c "exec $probe" >/dev/null 2>&1; then
          doctor_status present manual-command "$name"
        else
          DOCTOR_FAILURES=$((DOCTOR_FAILURES + 1))
          doctor_status probe-failed manual-command "$name"
        fi
        ;;
      app)
        effective_path=$DOCTOR_APPLICATIONS_ROOT$probe
        if [ -e "$effective_path" ]; then
          doctor_status present manual-app "$name"
        else
          doctor_status warning manual-app "$name"
        fi
        ;;
      auth)
        probe_command=${probe%% *}
        if command -v "$probe_command" >/dev/null 2>&1 && \
          run_with_timeout "$DOCTOR_AUTH_TIMEOUT_SECONDS" \
            /bin/bash -c "exec $probe" >/dev/null 2>&1; then
          doctor_status ready auth "$name"
        else
          doctor_status needs-login auth "$name"
        fi
        ;;
    esac
  done < <(dotfiles_manifest setup/manual-checks.tsv setup/manual-checks.local.tsv)
}

check_outdated() {
  local package_name
  if run_with_timeout 15 \
    "$DOTFILES_BREW_COMMAND" outdated --quiet \
    > "$doctor_tmp/outdated" 2>/dev/null; then
    while IFS= read -r package_name; do
      if [ -n "$package_name" ]; then
        doctor_status warning outdated "$package_name"
      fi
    done < "$doctor_tmp/outdated"
  else
    doctor_status warning outdated-check unavailable
  fi
}

# `brew bundle check` used to run here as a second opinion, but it re-failed
# every cask that check_casks had deliberately accepted as present-manual, so a
# machine with a hand-installed app could never reach a green doctor. The tap,
# formula and cask checks above already cover the same manifests.

main() {
  case "$DOCTOR_AUTH_TIMEOUT_SECONDS" in
    ''|*[!0-9]*|0)
      dotfiles_die 'DOCTOR_AUTH_TIMEOUT_SECONDS must be a positive integer'
      return 1
      ;;
  esac
  dotfiles_make_tmp dotfiles-doctor
  doctor_tmp=$DOTFILES_TMP

  load_brew_state
  check_taps
  check_formulae
  check_casks
  check_node
  check_uv_tools
  check_config
  check_manual_state
  check_outdated

  if [ "$DOCTOR_FAILURES" -ne 0 ]; then
    printf 'Doctor found %s required issue(s).\n' "$DOCTOR_FAILURES"
    return 1
  fi
  printf 'Doctor found no required issues.\n'
}

main "$@"
