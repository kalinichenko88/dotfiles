#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/zsh-config.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
tracked_zsh=$tmp/tracked-zsh
mutated_zsh=$tmp/mutated-zsh
mkdir -p "$tracked_zsh" "$mutated_zsh" \
  "$tmp/home/.openclaw/completions" "$tmp/bin"
git -C "$TEST_ROOT" ls-files 'zsh/zshrc' 'zsh/*.zsh' \
  > "$tmp/tracked-zsh-files"

# grep, not ripgrep: this has to run on a bare macOS runner. A missing tool
# used to look exactly like a clean result here.
assert_tracked_zsh_is_portable() {
  local source_root tracked_file grep_status
  source_root=$1

  while IFS= read -r tracked_file; do
    grep -nE '/Users/[^/]+/|\.bun/(bin|_bun)|BUN_INSTALL|python@[0-9]' \
      "$source_root/$tracked_file" && return 1
    grep_status=$?
    [ "$grep_status" -eq 1 ] || \
      fail "portability check could not read $tracked_file"
  done < "$tmp/tracked-zsh-files"
}

if ! assert_tracked_zsh_is_portable "$TEST_ROOT"; then
  fail 'non-portable Zsh path remains'
fi

local_source_count=$(grep -cE 'source .*local\.zsh' "$TEST_ROOT/zsh/zshrc" || true)
assert_equals '1' "$local_source_count"
# $HOME must remain literal in the tracked configuration.
# shellcheck disable=SC2016
assert_file_contains "$TEST_ROOT/zsh/path.zsh" 'export NVM_DIR="$HOME/.nvm"'

# One file per invocation: `zsh -n a b` parses only a and hands b to it as $1,
# so every extra argument was silently unchecked.
while IFS= read -r tracked_file; do
  zsh -n "$TEST_ROOT/$tracked_file" || fail "zsh syntax error in $tracked_file"
done < "$tmp/tracked-zsh-files"

# The Brewfile installs a keg-only python, so the unversioned python and pip
# only exist if libexec is on PATH — without a pinned version in the path.
if grep -q '^brew "python@' "$TEST_ROOT/Brewfile"; then
  assert_file_contains "$TEST_ROOT/zsh/path.zsh" '/opt/homebrew/opt/python@*/libexec/bin'
fi

while IFS= read -r tracked_file; do
  [ "$tracked_file" != 'zsh/local.zsh' ] || continue
  cp "$TEST_ROOT/$tracked_file" "$tracked_zsh/${tracked_file##*/}"
  cp "$TEST_ROOT/$tracked_file" "$mutated_zsh/${tracked_file##*/}"
done < "$tmp/tracked-zsh-files"

ignored_zsh=$tmp/ignored-zsh
mkdir -p "$ignored_zsh/zsh"
while IFS= read -r tracked_file; do
  cp "$TEST_ROOT/$tracked_file" "$ignored_zsh/$tracked_file"
done < "$tmp/tracked-zsh-files"
printf '%s\n' \
  'source /Users/example/.openclaw/completions/openclaw.zsh' \
  > "$ignored_zsh/zsh/local.zsh"
if ! assert_tracked_zsh_is_portable "$ignored_zsh"; then
  fail 'ignored local.zsh affected tracked Zsh portability check'
fi

# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf sourced > "$COMPLETION_MARKER"\n' > \
  "$tmp/home/.openclaw/completions/openclaw.zsh"
printf '#!/bin/sh\nprintf ":\\n"\n' > "$tmp/bin/starship"
chmod +x "$tmp/bin/starship"

# The payload must remain literal until the mutated Zsh configuration is sourced.
# shellcheck disable=SC2016
printf '%s\n' \
  'openclaw_completion="$HOME/.openclaw/completions/openclaw.zsh"' \
  '[[ -r "$openclaw_completion" ]] && source "$openclaw_completion"' \
  'unset openclaw_completion' >> "$mutated_zsh/zshrc"

if HOME="$tmp/home" COMPLETION_MARKER="$tmp/mutated-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c \
  'source "$1"; [ ! -e "$COMPLETION_MARKER" ]' \
  zsh "$mutated_zsh/zshrc"; then
  fail 'OpenClaw-loader mutation was not detected'
fi
[ -e "$tmp/mutated-marker" ] || \
  fail 'OpenClaw-loader mutation did not exercise the completion fixture'

HOME="$tmp/home" COMPLETION_MARKER="$tmp/completion-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c 'source "$1"; :' zsh "$tracked_zsh/zshrc"
[ ! -e "$tmp/completion-marker" ] || \
  fail 'tracked Zsh configuration must not source OpenClaw completions'

# Claude Code clears the title to an empty string on exit, and WezTerm keeps
# it: the tab stays blank unless the next prompt sets it again.
mkdir -p "$tmp/home/project"
prompt_output() {
  # shellcheck disable=SC2016
  (cd "$tmp/home/project" && HOME="$tmp/home" PATH="$tmp/bin:$PATH" TERM=$1 \
    zsh -f -c 'source "$1" > /dev/null; for f in $precmd_functions; do "$f"; done' \
    zsh "$tracked_zsh/zshrc")
}
title=$(prompt_output xterm-256color)
[ "$title" = $'\e]2;project\a' ] || \
  fail "prompt must set the tab title to the directory, got: $(printf %q "$title")"
# A dumb terminal prints the escape sequence as text before every prompt.
title=$(prompt_output dumb)
[ -z "$title" ] || \
  fail "prompt must not send a title to a dumb terminal, got: $(printf %q "$title")"

# After a reboot agterm replays the argv each pane ran. A replayed bare claude
# would open a new conversation; the wrapper must resume the tab's own one, also
# when the pane was started through the cc alias.
ln -s "$TEST_ROOT/tests/fixtures/bin/claude" "$tmp/bin/claude"
tab_id=0f1e2d3c-4b5a-4978-8695-a4b3c2d1e0f9
# The stub goes first only after zshrc: path.zsh puts Homebrew, where a real
# claude may live, ahead of whatever PATH the shell started with.
claude_argv() {
  : > "$tmp/claude.log"
  # shellcheck disable=SC2016
  HOME="$tmp/home" AGTERM_SESSION_ID=$tab_id CLAUDE_STUB_LOG=$tmp/claude.log \
    zsh -f -c 'source "$1" > /dev/null; path=("$3" $path); eval "$2"' \
    zsh "$tracked_zsh/zshrc" "$1" "$tmp/bin"
  cut -d' ' -f2- "$tmp/claude.log"
}
cc_flags='--dangerously-skip-permissions --permission-mode acceptEdits'
assert_equals "--session-id $tab_id $cc_flags" "$(claude_argv cc)"
# cc typed in the Russian layout is сс.
assert_equals "--session-id $tab_id $cc_flags" "$(claude_argv сс)"
mkdir -p "$tmp/home/.claude/projects/-project"
printf '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-01-01T00:00:00.000Z","sessionId":"%s","content":"hello"}\n' \
  "$tab_id" > "$tmp/home/.claude/projects/-project/$tab_id.jsonl"
assert_equals "--resume $tab_id $cc_flags" \
  "$(claude_argv "'claude' '--session-id' '$tab_id' $cc_flags")"

# agterm's Install Agent Status Hooks writes through the ~/.zshrc symlink, and
# appends its block with an absolute path unless this begin marker is present
# (rcMarkerBegin in agterm's AgentHooksInstall.swift).
assert_file_contains "$TEST_ROOT/zsh/zshrc" '# >>> agterm agent-status >>>'
mkdir -p "$tmp/home/.config/agterm/agent-status/shell"
# shellcheck disable=SC2016
printf ': > "$AGENT_STATUS_MARKER"\n' > \
  "$tmp/home/.config/agterm/agent-status/shell/integration.sh"
HOME="$tmp/home" AGENT_STATUS_MARKER="$tmp/agent-status-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c 'source "$1" > /dev/null; :' zsh "$tracked_zsh/zshrc"
[ -e "$tmp/agent-status-marker" ] || \
  fail 'zshrc must source the agterm agent-status integration from the home directory'

# nvm use replaces its own PATH entry in place, so a directory ahead of it
# shadows every Node it selects. Installers append such lines to ~/.zshrc, the
# symlink to zshrc: one put ~/.local/bin, with a foreign node link, first.
mkdir -p "$tmp/home/.nvm"
# shellcheck disable=SC2016
printf '%s\n' 'path=("$NVM_DIR/versions/node/v0/bin" $path)' \
  > "$tmp/home/.nvm/nvm.sh"
# shellcheck disable=SC2016
first_path=$(HOME="$tmp/home" AGENT_STATUS_MARKER="$tmp/agent-status-marker" \
  PATH="$tmp/bin:$PATH" zsh -f -c \
  'source "$1" > /dev/null; print -r -- $path[1]' zsh "$tracked_zsh/zshrc")
assert_equals "$tmp/home/.nvm/versions/node/v0/bin" "$first_path"

# Herdr gives a lost terminal (a reboot, a core crash) a bare shell with the
# same HC_TERMINAL_ID and never runs claude again. The stub plays claude: it
# runs the real SessionStart hook, then, for a reboot, kills its own shell.
# It logs each argument in brackets, so a split or a joined argument shows.
herdr_bin=$tmp/herdr-bin
mkdir -p "$herdr_bin" "$tmp/home/herdr-project"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/bash' \
  '{ printf %s "$PWD"; printf " [%s]" "$@"; echo; } >> "$HERDR_STUB_LOG"' \
  'printf "{\"session_id\":\"%s\",\"source\":\"startup\"}" "$HERDR_STUB_SID" | bash "$HERDR_HOOK"' \
  '[ -z "${HERDR_STUB_REBOOT:-}" ] || kill -KILL "$PPID"' > "$herdr_bin/claude"
chmod +x "$herdr_bin/claude"
herdr_sid=5f0c1d2e-3a4b-4c5d-8e6f-7a8b9c0d1e2f
herdr_mark=$tmp/state/claude-herdr/t9z
herdr_shell() {
  local cmd=$1
  shift
  : > "$tmp/herdr.log"
  # shellcheck disable=SC2016
  (cd "$tmp/home" && env -u CLAUDECODE HOME="$tmp/home" \
    XDG_STATE_HOME="$tmp/state" HC_TERMINAL_ID=t9z \
    HERDR_STUB_LOG="$tmp/herdr.log" HERDR_STUB_SID=$herdr_sid \
    HERDR_HOOK="$TEST_ROOT/claude/hooks/herdr-claude-session.sh" "$@" \
    zsh -f -c 'source "$1" > /dev/null; path=("$2" $path); eval "$3"' \
    zsh "$tracked_zsh/zshrc" "$herdr_bin" "$cmd") 2>/dev/null || true
}
# shellcheck disable=SC2016
resume_prompt='for f in $precmd_functions; do "$f"; done > /dev/null'
project=$(cd "$tmp/home/herdr-project" && pwd)
cc_logged='[--dangerously-skip-permissions] [--permission-mode] [acceptEdits]'

herdr_shell 'cd herdr-project && cc'
assert_equals "$project $cc_logged" "$(cat "$tmp/herdr.log")"
[ ! -e "$herdr_mark" ] || fail 'claude that exits must leave no Herdr mark'

herdr_shell "cd herdr-project && cc --append-system-prompt 'a b'" HERDR_STUB_REBOOT=1
assert_equals "$herdr_sid" "$(cat "$herdr_mark.session")"
herdr_shell "$resume_prompt"
assert_equals \
  "$project [--resume] [$herdr_sid] $cc_logged [--append-system-prompt] [a b]" \
  "$(cat "$tmp/herdr.log")"
[ ! -e "$herdr_mark" ] || fail 'the resumed claude must clear its Herdr mark'

# A shell that Claude Code itself starts in that terminal resumes nothing.
herdr_shell 'cd herdr-project && cc' HERDR_STUB_REBOOT=1
herdr_shell "$resume_prompt" CLAUDECODE=1
assert_equals '' "$(cat "$tmp/herdr.log")"

pass 'tracked Zsh configuration is portable'
