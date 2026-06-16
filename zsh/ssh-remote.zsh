# Portable nvim + remote prompt + wezterm title over ssh.
# Auto-sourced by zsh/zshrc (loops over zsh/*.zsh). Defines an ssh() wrapper that,
# for a bare interactive `ssh <host>`, ships a self-contained bundle to the host
# and launches a shell wired to our prompt + nvim. Anything else passes through.

# Repo root from THIS file's path (no dependency on $DOTFILES).
_DFR_REPO="${${(%):-%x}:A:h:h}"
_DFR_BUNDLE="$_DFR_REPO/ssh-remote/bundle"

# --- pure helpers (unit-tested) -------------------------------------------------

# Echo the single operand and return 0 iff argv is the bare form:
# zero option flags, exactly one operand ([user@]host), no remote command.
_dfr_bare_host() {
  emulate -L zsh
  local operand="" a
  for a in "$@"; do
    [[ "$a" == -* ]] && return 1
    [[ -n "$operand" ]] && return 1
    operand="$a"
  done
  [[ -n "$operand" ]] || return 1
  print -r -- "$operand"
}

# Wrapper around `ssh -G` so tests can stub config resolution.
_dfr_ssh_config() { command ssh -G "$1" 2>/dev/null }

# Return 0 (=> passthrough) if the host's effective config makes a bare login
# non-plain: remote command / forwarding / no-tty / forkafterauth / localcommand.
# proxyjump/proxycommand/controlmaster are NOT triggers (valid interactive logins).
_dfr_should_passthrough_cfg() {
  emulate -L zsh
  local cfg; cfg="$(_dfr_ssh_config "$1")" || return 0
  local key val permit_local=0 has_localcommand=0
  while IFS=' ' read -r key val; do
    case "$key" in
      remotecommand) [[ -n "$val" && "$val" != none ]] && return 0 ;;
      localforward|remoteforward|dynamicforward) [[ -n "$val" ]] && return 0 ;;
      sessiontype) [[ "$val" == none ]] && return 0 ;;
      # `ssh -G` prints RequestTTY=no as `false` on OpenSSH >=8/10; older
      # builds print `no`. Match both so no-TTY hosts pass through.
      requesttty) [[ "$val" == no || "$val" == false ]] && return 0 ;;
      forkafterauthentication) [[ "$val" == yes ]] && return 0 ;;
      permitlocalcommand) [[ "$val" == yes ]] && permit_local=1 ;;
      localcommand) [[ -n "$val" && "$val" != none ]] && has_localcommand=1 ;;
    esac
  done <<< "$cfg"
  (( permit_local && has_localcommand )) && return 0
  return 1
}

# --- wezterm title via user-var (base64) ---------------------------------------
_dfr_set_title() {
  local b64; b64="$(printf '%s' "$1" | base64 | tr -d '\n')"
  printf '\e]1337;SetUserVar=ssh_host=%s\a' "$b64"
}
_dfr_clear_title() { printf '\e]1337;SetUserVar=ssh_host=\a' }

# --- the wrapper ----------------------------------------------------------------
ssh() {
  emulate -L zsh
  setopt local_options local_traps

  # Fast passthroughs.
  [[ -n "$SSH_NO_BUNDLE" ]] && { command ssh "$@"; return }
  [[ -t 0 && -t 1 ]]       || { command ssh "$@"; return }

  local host
  host="$(_dfr_bare_host "$@")"        || { command ssh "$@"; return }
  _dfr_should_passthrough_cfg "$host"  && { command ssh "$@"; return }

  # Intercept: one shared ControlMaster for mkdir + rsync + final connect. The path
  # is keyed on this shell's PID ($$) too, so concurrent sessions to the same host
  # (separate terminals) get separate masters and one exiting can't drop the other.
  local remote='~/.dotfiles-remote/bundle'
  local -a cm=(-o ControlMaster=auto -o ControlPersist=30 \
               -o "ControlPath=$HOME/.ssh/cm-dotfiles-%r@%h-%p-$$")

  # Refuse to sync into a symlinked bundle dir: rsync --delete (below) follows a
  # symlinked destination and would wipe files in its target. A symlinked PARENT
  # (~/.dotfiles-remote relocated to another volume) is fine — deletes stay
  # confined to the real bundle/ dir, so only the rsync target itself is guarded.
  if ! command ssh -T "${cm[@]}" "$host" "[ -L $remote ] && exit 1; mkdir -p $remote" 2>/dev/null; then
    print -u2 "ssh-remote: cannot prepare $host; using plain ssh."
    command ssh "${cm[@]}" -O exit "$host" 2>/dev/null
    command ssh -t "$host"; return $?
  fi

  if command -v rsync >/dev/null 2>&1 && \
     command rsync -az --delete --exclude='.git/' -e "ssh -T ${cm[*]}" \
       "$_DFR_BUNDLE/" "$host:$remote/" >/dev/null 2>&1; then
    :
  elif command tar -C "$_DFR_BUNDLE" --exclude='.git' -cf - . 2>/dev/null | \
       command ssh -T "${cm[@]}" "$host" "tar -C $remote -xf -" 2>/dev/null; then
    :
  else
    print -u2 "ssh-remote: bundle sync failed; using plain ssh."
    command ssh -t "$host"; local rc=$?
    command ssh "${cm[@]}" -O exit "$host" 2>/dev/null
    return $rc
  fi

  # On SIGINT (e.g. Ctrl-C during connect) clean up title + master too. local_traps
  # (set above) makes this trap function-local and auto-restored on return.
  _dfr_set_title "$host"
  trap '_dfr_clear_title; command ssh "${cm[@]}" -O exit "$host" 2>/dev/null' INT
  command ssh -t "${cm[@]}" "$host" "exec sh $remote/bootstrap.sh"
  local rc=$?
  trap - INT
  _dfr_clear_title
  command ssh "${cm[@]}" -O exit "$host" 2>/dev/null
  return $rc
}
