#!/bin/bash

set -euo pipefail

unset CDPATH
SCRIPT_DIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# The common library path is derived from this script at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf 'Usage: %s {all|brew|tools|config [unit]|update}\n' "$0" >&2
}

# A first run trips on things bootstrap cannot fix for the machine: a cask
# whose application is already in /Applications and cannot be adopted, a file
# it refuses to overwrite without FORCE=1. Stopping at the first one leaves
# everything after it unprovisioned and makes the whole run start over, so a
# step records its failure, the run continues, and the list is reported at the
# end with a non-zero exit.
DOTFILES_FAILED_STEPS=

run_step() {
  local name status
  name=$1
  shift
  status=0
  "$@" || status=$?
  if [ "$status" -ne 0 ]; then
    DOTFILES_FAILED_STEPS="${DOTFILES_FAILED_STEPS:+$DOTFILES_FAILED_STEPS, }$name"
    dotfiles_warn "$name failed; continuing with the rest"
  fi
  return 0
}

report_failed_steps() {
  [ -n "$DOTFILES_FAILED_STEPS" ] || return 0
  dotfiles_die "finished with failures: $DOTFILES_FAILED_STEPS"
}

check_platform() {
  local system architecture
  system=$(uname -s)
  architecture=$(uname -m)

  if [ "$system" != Darwin ] || [ "$architecture" != arm64 ]; then
    dotfiles_die "this bootstrap supports Apple Silicon macOS only (found $system/$architecture)"
    return 1
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    dotfiles_die 'Command Line Tools are missing; run: xcode-select --install'
    return 1
  fi
}

# The character class is the validation: an unsafe or malformed value simply
# does not match, leaving NVM_VERSION empty.
load_tool_versions() {
  NVM_VERSION=$(sed -n 's/^NVM_VERSION=\([A-Za-z0-9._-]*\)$/\1/p' \
    "$DOTFILES_ROOT/setup/tool-versions.env")
  if [ -z "$NVM_VERSION" ]; then
    dotfiles_die 'setup/tool-versions.env has no usable NVM_VERSION'
    return 1
  fi
}

install_homebrew() {
  local brew_command installer installer_url
  installer_url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  brew_command=${DOTFILES_HOMEBREW_BIN:-/opt/homebrew/bin/brew}

  if [ -x "$brew_command" ]; then
    dotfiles_resolve_homebrew
    brew_command=$DOTFILES_BREW_COMMAND
  else
    if [ "${INSTALL_HOMEBREW:-0}" != 1 ]; then
      dotfiles_die 'Homebrew is missing; rerun with INSTALL_HOMEBREW=1 to authorize the official installer'
      return 1
    fi

    if [ "${DRY_RUN:-0}" = 1 ]; then
      dotfiles_print_command /bin/bash -c "\$(curl -fsSL $installer_url)"
    else
      if ! command -v curl >/dev/null 2>&1; then
        dotfiles_die 'curl is required to install Homebrew'
        return 1
      fi
      installer=$(curl -fsSL "$installer_url")
      /bin/bash -c "$installer"
    fi
  fi

  if [ "${DRY_RUN:-0}" != 1 ] && [ ! -x "$brew_command" ]; then
    dotfiles_die "Homebrew installer completed but $brew_command is unavailable"
    return 1
  fi
  if [ "${DRY_RUN:-0}" != 1 ]; then
    dotfiles_resolve_homebrew
    brew_command=$DOTFILES_BREW_COMMAND
    # The installer only writes shellenv into ~/.zprofile, which this process
    # never reads. Without this, the tools layer cannot see what brew installs.
    eval "$("$brew_command" shellenv)"
  fi

  install_brew_bundles "$brew_command"
}

# Homebrew refuses to load a formula or cask from a third-party tap until that
# tap is trusted, and `brew bundle` aborts on the first one — which on a new
# machine is every tap here. Declaring a tap in a Brewfile is that decision, so
# apply it rather than making the user run `brew trust` and start over. Taps
# arrive both as `tap "owner/name"` and inside a qualified `brew`/`cask` token.
trust_brewfile_taps() {
  local brew_command brewfile tap
  brew_command=$1
  brewfile=$2

  while IFS= read -r tap; do
    [ -n "$tap" ] || continue
    dotfiles_run "$brew_command" trust --tap "$tap"
  done < <(sed -n -E \
    -e 's/^tap "([^"]+)".*/\1/p' \
    -e 's/^(brew|cask) "([^"\/]+\/[^"\/]+)\/[^"]+".*/\2/p' \
    "$brewfile" | sort -u)
}

# Brewfile holds the shared baseline; the gitignored Brewfile.local holds
# software that belongs to this machine only.
install_brew_bundles() {
  local brew_command brewfile
  brew_command=$1

  # Recorded rather than fatal: `brew bundle` installs everything it can and
  # then reports what it could not, and one unadoptable application must not
  # cost the machine its shell and editor configuration.
  for brewfile in "$DOTFILES_ROOT/Brewfile" "$DOTFILES_ROOT/Brewfile.local"; do
    [ -f "$brewfile" ] || continue
    trust_brewfile_taps "$brew_command" "$brewfile"
    run_step "${brewfile##*/}" \
      dotfiles_run "$brew_command" bundle install --file "$brewfile"
  done
}

update_workstation() {
  dotfiles_resolve_homebrew
  dotfiles_run "$DOTFILES_BREW_COMMAND" update
  install_brew_bundles "$DOTFILES_BREW_COMMAND"
  dotfiles_run "$DOTFILES_BREW_COMMAND" upgrade
  # Doctor checks the runtime and configuration manifests too, so update has to
  # apply everything it then verifies, or it reports drift it declined to fix.
  install_tools
  install_config
  dotfiles_run "$SCRIPT_DIR/doctor.sh"
}

install_node_versions() {
  local node_version node_versions_file
  node_versions_file=$DOTFILES_ROOT/setup/node-versions.txt
  export NVM_DIR=$DOTFILES_TARGET_HOME/.nvm

  if [ "${DRY_RUN:-0}" = 1 ]; then
    dotfiles_print_command source "$NVM_DIR/nvm.sh"
    while IFS= read -r node_version || [ -n "$node_version" ]; do
      case "$node_version" in
        ''|'#'*) continue ;;
      esac
      dotfiles_print_command nvm install "$node_version"
      dotfiles_print_command nvm alias default "$node_version"
    done < "$node_versions_file"
    return 0
  fi

  # NVM is installed into the selected target home.
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  while IFS= read -r node_version || [ -n "$node_version" ]; do
    case "$node_version" in
      ''|'#'*) continue ;;
    esac
    nvm install "$node_version"
    nvm alias default "$node_version"
  done < "$node_versions_file"
}

install_uv_tools() {
  local tool_spec tools_file
  tools_file=$DOTFILES_ROOT/setup/uv-tools.txt

  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v uv >/dev/null 2>&1; then
    dotfiles_die 'uv is required to install UV-managed tools; run the Brew layer first'
    return 1
  fi

  while IFS= read -r tool_spec || [ -n "$tool_spec" ]; do
    case "$tool_spec" in
      ''|'#'*) continue ;;
    esac
    dotfiles_run uv tool install --force "$tool_spec"
  done < "$tools_file"
}

print_manual_command_checks() {
  local kind name probe
  printf 'Manual command checks:\n'
  while IFS=$'\t' read -r kind name probe || [ -n "${kind:-}" ]; do
    case "$kind" in
      command) printf '  - %s: %s\n' "$name" "$probe" ;;
    esac
  done < <(dotfiles_manifest setup/manual-checks.tsv setup/manual-checks.local.tsv)
}

announce_missing_git_identity() {
  local target
  target=$1

  dotfiles_path_exists "$target" && return 0
  # Deliberately not created from the example: a placeholder address satisfies
  # useConfigOnly, so Git would author commits as it instead of refusing. Git
  # ignores an includeIf whose path does not exist.
  dotfiles_info "not configured, commits there will be refused until you write it: $target"
}

# Per-event merge, not a wholesale replace: a user's hooks on events this
# repository does not declare have to keep firing.
install_claude_settings() {
  # $source is a jq variable, not a shell one.
  # shellcheck disable=SC2016
  dotfiles_merge_json claude/hooks-config.json \
    "$DOTFILES_TARGET_HOME/.claude/settings.json" \
    '.hooks = ((.hooks // {}) + $source[0])'
}

config_dev_dirs() {
  local directory
  # git/gitconfig selects the personal or work identity by these paths.
  for directory in Dev/Personal Dev/Work 'Dev/Open Source'; do
    if [ -d "$DOTFILES_TARGET_HOME/$directory" ]; then
      dotfiles_info "project directory already present: $directory"
      continue
    fi
    dotfiles_run mkdir -p "$DOTFILES_TARGET_HOME/$directory"
    dotfiles_info "created project directory: $directory"
  done
}

config_git() {
  dotfiles_link git/gitconfig "$DOTFILES_TARGET_HOME/.config/git/config"
  dotfiles_link git/gitconfig-personal \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-personal"
  announce_missing_git_identity \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-work"
  announce_missing_git_identity \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-local"
}

config_zsh() {
  dotfiles_link zsh/zshrc "$DOTFILES_TARGET_HOME/.zshrc"
}

config_nvim() {
  dotfiles_link nvim "$DOTFILES_TARGET_HOME/.config/nvim"
}

config_wezterm() {
  dotfiles_link wezterm.lua "$DOTFILES_TARGET_HOME/.wezterm.lua"
}

# Only the 1Password agent wiring is tracked. Hosts live in the untracked
# ~/.ssh/config.local, which the tracked file includes first.
config_ssh() {
  dotfiles_run mkdir -p "$DOTFILES_TARGET_HOME/.ssh"
  dotfiles_run chmod 700 "$DOTFILES_TARGET_HOME/.ssh"
  dotfiles_link ssh/config "$DOTFILES_TARGET_HOME/.ssh/config"
}

# Applied through `gh config set`, never symlinked: gh writes its own state
# into this file — it added `version: "1"` the first time the link was in
# place, dirtying the repository — so the file has to stay gh's own.
config_gh() {
  local key value
  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v gh >/dev/null 2>&1; then
    dotfiles_warn 'gh is unavailable; skipping its preferences'
    return 0
  fi
  while IFS=': ' read -r key value; do
    [ -n "$key" ] || continue
    case "$key" in '#'*) continue ;; esac
    dotfiles_run gh config set "$key" "$value"
  done < "$DOTFILES_ROOT/gh/config.yml"
}

config_starship() {
  dotfiles_link starship/starship.toml \
    "$DOTFILES_TARGET_HOME/.config/starship.toml"
}

# Merged, never copied: `docker login` writes registry credentials into the
# same file, and replacing it would log the user out of every registry.
config_docker() {
  dotfiles_merge_json docker/config.json \
    "$DOTFILES_TARGET_HOME/.docker/config.json"
}

config_claude() {
  local item item_name
  for item in "$DOTFILES_ROOT"/claude/skills/*; do
    [ -d "$item" ] || continue
    item_name=$(basename -- "$item")
    dotfiles_link "claude/skills/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/skills/$item_name"
  done
  for item in "$DOTFILES_ROOT"/claude/hooks/*.sh; do
    [ -f "$item" ] || continue
    item_name=$(basename -- "$item")
    dotfiles_link "claude/hooks/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/hooks/$item_name"
  done
  install_claude_settings
}

CONFIG_UNITS='dev-dirs git ssh zsh nvim wezterm gh starship docker claude'

install_config() {
  local requested unit matched
  requested=${1:-all}
  matched=0

  for unit in $CONFIG_UNITS; do
    case "$requested" in
      all|"$unit")
        run_step "config $unit" "config_${unit//-/_}"
        matched=1
        ;;
    esac
  done

  if [ "$matched" -ne 1 ]; then
    dotfiles_die "unknown config unit: $requested (known: $CONFIG_UNITS)"
    return 1
  fi
}

install_tools() {
  local nvm_dir nvm_url existing_origin
  nvm_dir=$DOTFILES_TARGET_HOME/.nvm
  nvm_url=https://github.com/nvm-sh/nvm.git
  load_tool_versions

  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v git >/dev/null 2>&1; then
    dotfiles_die 'git is required to install user-space tools; run the Brew layer first'
    return 1
  fi

  if [ -e "$nvm_dir" ] && [ ! -d "$nvm_dir/.git" ]; then
    dotfiles_die "NVM destination exists but is not a Git checkout: $nvm_dir"
    return 1
  fi
  if [ -d "$nvm_dir/.git" ]; then
    if ! existing_origin=$(git -C "$nvm_dir" remote get-url origin 2>/dev/null) || \
      [ "$existing_origin" != "$nvm_url" ]; then
      dotfiles_die 'NVM checkout has an unexpected origin'
      return 1
    fi
    dotfiles_run git -C "$nvm_dir" fetch --tags --force origin
  else
    dotfiles_run git clone "$nvm_url" "$nvm_dir"
  fi
  dotfiles_run git -C "$nvm_dir" checkout --detach "$NVM_VERSION"
  install_node_versions
  install_uv_tools
  print_manual_command_checks
}

verify_target() {
  local marker
  marker=$DOTFILES_TARGET_HOME/.config/dotfiles/bootstrap-complete
  # Explicit, because run_step calls this with errexit suspended: a failing
  # doctor must not go on to write the marker that says it passed.
  dotfiles_run env \
    "DOTFILES_ROOT=$DOTFILES_ROOT" \
    "DOTFILES_TARGET_HOME=$DOTFILES_TARGET_HOME" \
    "$SCRIPT_DIR/doctor.sh" || return 1
  dotfiles_prepare_parent "$marker"
  dotfiles_run touch "$marker"
  dotfiles_info "target bootstrap verified: $marker"
}

main() {
  local command
  command=${1:-}
  check_platform

  case "$command" in
    brew) install_homebrew ;;
    tools) install_tools ;;
    all)
      # Not guarded: without Homebrew at the expected prefix there is no run to
      # continue. Package failures inside it are recorded, the layer is not.
      install_homebrew
      run_step 'user-space tools' install_tools
      install_config
      run_step verification verify_target
      ;;
    config) install_config "${2:-all}" ;;
    update) update_workstation ;;
    *)
      usage
      return 1
      ;;
  esac

  report_failed_steps
}

main "$@"
