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

load_tool_versions() {
  local line key value versions_file
  versions_file=$DOTFILES_ROOT/setup/tool-versions.env
  NVM_VERSION=

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    key=${line%%=*}
    value=${line#*=}
    if [ "$key" = "$line" ] || [ -z "$value" ]; then
      dotfiles_die "invalid tool version record: $key"
      return 1
    fi
    case "$value" in
      *[!A-Za-z0-9._-]*)
        dotfiles_die "unsafe tool version value for $key"
        return 1
        ;;
    esac
    case "$key" in
      NVM_VERSION) NVM_VERSION=$value ;;
      *)
        dotfiles_die "unknown tool version key: $key"
        return 1
        ;;
    esac
  done < "$versions_file"

  if [ -z "$NVM_VERSION" ]; then
    dotfiles_die 'tool version manifest is incomplete'
    return 1
  fi
}

install_git_checkout() {
  local name url destination revision existing_origin
  name=$1
  url=$2
  destination=$3
  revision=$4

  if [ -e "$destination" ] && [ ! -d "$destination/.git" ]; then
    dotfiles_die "$name destination exists but is not a Git checkout: $destination"
    return 1
  fi
  if [ -d "$destination/.git" ]; then
    if ! existing_origin=$(git -C "$destination" remote get-url origin 2>/dev/null) || \
      [ "$existing_origin" != "$url" ]; then
      dotfiles_die "$name checkout has an unexpected origin"
      return 1
    fi
  fi

  if [ ! -e "$destination" ]; then
    dotfiles_run git clone "$url" "$destination"
  else
    dotfiles_run git -C "$destination" fetch --tags --force origin
  fi
  dotfiles_run git -C "$destination" checkout --detach "$revision"
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

# Brewfile holds the shared baseline; the gitignored Brewfile.local holds
# software that belongs to this machine only.
install_brew_bundles() {
  local brew_command
  brew_command=$1
  dotfiles_run "$brew_command" bundle install --file "$DOTFILES_ROOT/Brewfile"
  if [ -f "$DOTFILES_ROOT/Brewfile.local" ]; then
    dotfiles_run "$brew_command" bundle install \
      --file "$DOTFILES_ROOT/Brewfile.local"
  fi
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

copy_git_template_if_missing() {
  local relative_source target
  relative_source=$1
  target=$2

  if dotfiles_path_exists "$target"; then
    dotfiles_info "preserving machine-local Git config: $target"
    return 0
  fi

  dotfiles_prepare_parent "$target"
  dotfiles_run cp "$DOTFILES_ROOT/$relative_source" "$target"
  dotfiles_info "created Git config template: $target"
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
  copy_git_template_if_missing git/gitconfig-work.example \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-work"
  copy_git_template_if_missing git/gitconfig-local.example \
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

config_gh() {
  dotfiles_link gh/config.yml "$DOTFILES_TARGET_HOME/.config/gh/config.yml"
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

CONFIG_UNITS='dev-dirs git zsh nvim wezterm gh starship docker claude'

install_config() {
  local requested unit matched
  requested=${1:-all}
  matched=0

  for unit in $CONFIG_UNITS; do
    case "$requested" in
      all|"$unit")
        "config_${unit//-/_}"
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
  load_tool_versions

  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v git >/dev/null 2>&1; then
    dotfiles_die 'git is required to install user-space tools; run the Brew layer first'
    return 1
  fi

  install_git_checkout \
    'NVM' \
    'https://github.com/nvm-sh/nvm.git' \
    "$DOTFILES_TARGET_HOME/.nvm" \
    "$NVM_VERSION"
  install_node_versions
  install_uv_tools
  print_manual_command_checks
}

verify_target() {
  local marker
  marker=$DOTFILES_TARGET_HOME/.config/dotfiles/bootstrap-complete
  dotfiles_run env \
    "DOTFILES_ROOT=$DOTFILES_ROOT" \
    "DOTFILES_TARGET_HOME=$DOTFILES_TARGET_HOME" \
    "$SCRIPT_DIR/doctor.sh"
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
      install_homebrew
      install_tools
      install_config
      verify_target
      ;;
    config) install_config "${2:-all}" ;;
    update) update_workstation ;;
    *)
      usage
      return 1
      ;;
  esac
}

main "$@"
