#!/bin/bash

set -euo pipefail

unset CDPATH
SCRIPT_DIR=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# The common library path is derived from this script at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

trap dotfiles_cleanup_tmp EXIT

usage() {
  printf 'Usage: %s {all|brew|tools|config [unit]|update|cleanup|units}\n' "$0" >&2
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
  done < <(dotfiles_brewfile_records "$brewfile" | awk -F '\t' '
    $1 == "tap" { print $2; next }
    $2 ~ /\// { sub(/\/[^\/]*$/, "", $2); print $2 }
  ' | sort -u)
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

# Guarded the same way `all` is, and for the same reason: this is the command a
# second machine runs to catch up, and an offline `brew update` must not cost it
# the configuration it was going to apply afterwards.
update_workstation() {
  dotfiles_resolve_homebrew
  run_step 'brew update' dotfiles_run "$DOTFILES_BREW_COMMAND" update
  install_brew_bundles "$DOTFILES_BREW_COMMAND"
  run_step 'brew upgrade' dotfiles_run "$DOTFILES_BREW_COMMAND" upgrade
  # Doctor checks the runtime and configuration manifests too, so update has to
  # apply everything it then verifies, or it reports drift it declined to fix.
  run_step 'user-space tools' install_tools
  install_config
  run_step verification dotfiles_run "$SCRIPT_DIR/doctor.sh"
}

# `brew bundle cleanup` reads one Brewfile, and the shared baseline plus this
# machine's own manifest are two, so it gets both concatenated — pointing it at
# the tracked file alone would uninstall everything Brewfile.local declares.
#
# Never part of update: a package missing from a manifest is far more often an
# oversight than a decision. Without FORCE=1 Homebrew lists what it would remove
# and asks; FORCE=1 is what skips the question.
cleanup_workstation() {
  local combined
  dotfiles_resolve_homebrew
  dotfiles_make_tmp dotfiles-cleanup
  combined=$DOTFILES_TMP/Brewfile
  dotfiles_manifest Brewfile Brewfile.local > "$combined"
  # A manifest that came out empty would uninstall the entire machine.
  if ! grep -qE '^(brew|cask) "' "$combined"; then
    dotfiles_die 'refusing to clean up: the combined manifest declares nothing'
    return 1
  fi

  if [ "${FORCE:-0}" = 1 ]; then
    dotfiles_run "$DOTFILES_BREW_COMMAND" bundle cleanup --force --file "$combined"
    return 0
  fi
  dotfiles_info 'rerun with FORCE=1 to skip the confirmation'
  dotfiles_run "$DOTFILES_BREW_COMMAND" bundle cleanup --file "$combined"
}

install_node_versions() {
  local node_version node_versions_file
  node_versions_file=$DOTFILES_ROOT/setup/node-versions.txt
  export NVM_DIR=$DOTFILES_TARGET_HOME/.nvm

  if [ "${DRY_RUN:-0}" = 1 ]; then
    dotfiles_print_command source "$NVM_DIR/nvm.sh"
  else
    # NVM is installed into the selected target home.
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
  fi

  while IFS= read -r node_version || [ -n "$node_version" ]; do
    case "$node_version" in
      ''|'#'*) continue ;;
    esac
    dotfiles_run nvm install "$node_version"
    dotfiles_run nvm alias default "$node_version"
  done < "$node_versions_file"
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
  # One merge for the whole fragment: a second write into the same file would
  # back up the state the first one just produced, on a machine that had no
  # settings at all. The merge handles hooks and the status line alike, and
  # Claude Code expands the $HOME the fragment spells out, so a
  # public repository carries nobody's home directory.
  dotfiles_merge_json claude/settings-fragment.json \
    "$DOTFILES_TARGET_HOME/.claude/settings.json"
}

# Through the CLI, not the settings fragment: a plugin named only in
# settings.json is registered and never installed. Add and install are no-ops
# once done and fetch nothing, so the update is what brings a machine to the
# latest commit; it refreshes the marketplace itself. HOME aims all three at the
# target home like everything else this unit writes.
install_claude_plugin() {
  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v claude >/dev/null 2>&1; then
    dotfiles_warn 'claude is unavailable; skipping its plugin'
    return 0
  fi
  dotfiles_run env HOME="$DOTFILES_TARGET_HOME" \
    claude plugin marketplace add "$DOTFILES_CLAUDE_MARKETPLACE" || return 1
  dotfiles_run env HOME="$DOTFILES_TARGET_HOME" \
    claude plugin install "$DOTFILES_CLAUDE_PLUGIN" || return 1
  dotfiles_run env HOME="$DOTFILES_TARGET_HOME" \
    claude plugin update "$DOTFILES_CLAUDE_PLUGIN"
}

config_dev_dirs() {
  local directory status=0
  # git/gitconfig selects the personal or work identity by these paths.
  for directory in Dev/Personal Dev/Work 'Dev/Open Source'; do
    if [ -d "$DOTFILES_TARGET_HOME/$directory" ]; then
      dotfiles_info "project directory already present: $directory"
      continue
    fi
    if dotfiles_run mkdir -p "$DOTFILES_TARGET_HOME/$directory"; then
      dotfiles_info "created project directory: $directory"
    else
      status=1
    fi
  done
  return "$status"
}

# Installs every symlink setup/links.tsv declares for one unit. A unit whose
# whole definition is symlinks needs no function of its own. Every row is
# tried, and any refused row fails the unit: a loop returns only the status of
# its last row, which hid a refused first one.
config_links() {
  local source target status=0
  while IFS=$'\t' read -r _ source target; do
    dotfiles_link "$source" "$DOTFILES_TARGET_HOME/$target" || status=1
  done < <(dotfiles_links "$1")
  return "$status"
}

config_git() {
  local status=0
  config_links git || status=1
  announce_missing_git_identity \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-work"
  announce_missing_git_identity \
    "$DOTFILES_TARGET_HOME/.config/git/gitconfig-local"
  return "$status"
}

# Only the 1Password agent wiring is tracked. Hosts live in the untracked
# ~/.ssh/config.local, which the tracked file includes first.
config_ssh() {
  dotfiles_run mkdir -p "$DOTFILES_TARGET_HOME/.ssh"
  dotfiles_run chmod 700 "$DOTFILES_TARGET_HOME/.ssh"
  config_links ssh
}

# Every value the daemon sets is in effect, by the test doctor makes.
launch_daemon_in_effect() {
  local key value
  while IFS='=' read -r key value; do
    dotfiles_sysctl_reaches "$key" "$value" || return 1
  done < <(dotfiles_launch_daemon_sysctls "$1")
}

# Root-owned and outside every home, so this is the one step that goes through
# sudo. Nothing to do only when the copy is identical, launchd has it loaded
# and its values are in effect; anything less is loaded again rather than
# reported as installed (#52). Each test misses what another catches: a job
# that ran once stays loaded whatever its run did, and values set by hand pass
# while the load that keeps them across a boot failed. Otherwise bootout first,
# as launchd keeps a loaded definition and would not run a changed one; loading
# runs it at once, so the values apply without a reboot.
install_launch_daemon() {
  local source label target
  source=$DOTFILES_ROOT/$1
  label=$(basename -- "$1" .plist)
  if [ -z "$DOTFILES_LAUNCH_DAEMONS_DIR" ]; then
    dotfiles_info "system-wide, skipped for this target home: $label"
    return 0
  fi
  target=$DOTFILES_LAUNCH_DAEMONS_DIR/$label.plist
  if cmp -s "$source" "$target" && launch_daemon_in_effect "$1" &&
    launchctl print "system/$label" > /dev/null 2>&1; then
    dotfiles_info "launch daemon already installed: $target"
    return 0
  fi
  dotfiles_run sudo install -m 644 -o root -g wheel "$source" "$target" || return 1
  dotfiles_run sudo launchctl bootout "system/$label" 2>/dev/null || :
  dotfiles_run sudo launchctl bootstrap system "$target"
}

config_wezterm() {
  local status=0
  config_links wezterm || status=1
  install_launch_daemon "$DOTFILES_SOCKET_BUFFERS_DAEMON" || status=1
  return "$status"
}

# Merged, never linked: the Settings window rewrites settings.json atomically,
# so a symlink would turn back into a plain file on the first change. agterm
# reads the file at launch, and restoreMode applies only from a new launch.
config_agterm() {
  local status=0
  config_links agterm || status=1
  dotfiles_merge_json agterm/settings.json \
    "$DOTFILES_TARGET_HOME/Library/Application Support/agterm/settings.json" \
    || status=1
  return "$status"
}

# Applied through `gh config set`, never symlinked: gh writes its own state
# into this file — it added `version: "1"` the first time the link was in
# place, dirtying the repository — so the file has to stay gh's own.
# GH_CONFIG_DIR aims gh at the target home like everything else this unit writes.
config_gh() {
  local key value status=0
  if [ "${DRY_RUN:-0}" != 1 ] && ! command -v gh >/dev/null 2>&1; then
    dotfiles_warn 'gh is unavailable; skipping its preferences'
    return 0
  fi
  while IFS=': ' read -r key value; do
    [ -n "$key" ] || continue
    case "$key" in '#'*) continue ;; esac
    dotfiles_run env GH_CONFIG_DIR="$DOTFILES_TARGET_HOME/.config/gh" \
      gh config set "$key" "$value" || status=1
  done < "$DOTFILES_ROOT/gh/config.yml"
  return "$status"
}

# Merged, never copied: `docker login` writes registry credentials into the
# same file, and replacing it would log the user out of every registry.
config_docker() {
  dotfiles_merge_json docker/config.json \
    "$DOTFILES_TARGET_HOME/.docker/config.json"
}

config_claude() {
  local item item_name status=0
  config_links claude || status=1
  for item in "$DOTFILES_ROOT"/claude/skills/*; do
    [ -d "$item" ] || continue
    item_name=$(basename -- "$item")
    dotfiles_link "claude/skills/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/skills/$item_name" || status=1
  done
  for item in "$DOTFILES_ROOT"/claude/hooks/*.sh; do
    [ -f "$item" ] || continue
    item_name=$(basename -- "$item")
    dotfiles_link "claude/hooks/$item_name" \
      "$DOTFILES_TARGET_HOME/.claude/hooks/$item_name" || status=1
  done
  dotfiles_prune_orphan_links "$DOTFILES_TARGET_HOME/.claude"
  dotfiles_prune_orphan_links "$DOTFILES_TARGET_HOME/.claude/skills"
  dotfiles_prune_orphan_links "$DOTFILES_TARGET_HOME/.claude/hooks"
  # The one step that stops the unit: the plugin CLI writes the same
  # settings.json, and must not touch a file the merge could not parse.
  install_claude_settings || return 1
  install_claude_plugin || status=1
  return "$status"
}

CONFIG_UNITS='dev-dirs git ssh zsh nvim wezterm agterm gh starship docker claude'

# A unit with a function runs it; anything else is defined entirely by its rows
# in setup/links.tsv. run_step suspends set -e, so a unit function tries every
# step, records each failure in its own status and returns it: a failed link
# must fail the unit without costing it the merge or the install after it.
install_config_unit() {
  local unit function_name
  unit=$1
  function_name=config_${unit//-/_}
  if declare -F "$function_name" >/dev/null; then
    "$function_name"
  else
    config_links "$unit"
  fi
}

install_config() {
  local requested unit matched
  requested=${1:-all}
  matched=0

  for unit in $CONFIG_UNITS; do
    case "$requested" in
      all|"$unit")
        run_step "config $unit" install_config_unit "$unit"
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

  # Answered before the platform check: the Makefile asks for this list on every
  # invocation, including `make help`, and must not depend on the host.
  if [ "$command" = units ]; then
    printf '%s\n' "$CONFIG_UNITS"
    return 0
  fi

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
    cleanup) cleanup_workstation ;;
    *)
      usage
      return 1
      ;;
  esac

  report_failed_steps
}

main "$@"
