#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
target_home=$tmp/home
mkdir -p "$target_home/.claude" "$tmp/bin"

# The real claude would clone the plugin from GitHub; the stub records instead.
# The real sudo would prompt, or on CI change the runner; its stub records too.
# The real sysctl would answer with this machine's socket buffers.
ln -s "$TEST_ROOT/tests/fixtures/bin/claude" "$tmp/bin/claude"
ln -s "$TEST_ROOT/tests/fixtures/bin/sudo" "$tmp/bin/sudo"
ln -s "$TEST_ROOT/tests/fixtures/bin/sysctl" "$tmp/bin/sysctl"
export PATH="$tmp/bin:$PATH" CLAUDE_STUB_LOG=$tmp/claude.log \
  SUDO_STUB_LOG=$tmp/sudo.log

# What an older bootstrap left behind: the base prompt moved into the plugin,
# so the link into this repository now dangles.
ln -s "$TEST_ROOT/claude/CLAUDE.md" "$target_home/.claude/CLAUDE.md"

DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config

# Provisioning a home other than the user's own must not touch the machine.
[ ! -s "$tmp/sudo.log" ] || \
  fail "config for a temporary home ran sudo: $(cat "$tmp/sudo.log")"

assert_link() {
  expected=$1
  target=$2
  [ -L "$target" ] || fail "expected symlink at $target"
  assert_equals "$expected" "$(readlink "$target")"
}

assert_link "$TEST_ROOT/git/gitconfig" "$target_home/.config/git/config"
assert_link "$TEST_ROOT/git/gitconfig-personal" "$target_home/.config/git/gitconfig-personal"
assert_link "$TEST_ROOT/zsh/zshrc" "$target_home/.zshrc"
assert_link "$TEST_ROOT/nvim" "$target_home/.config/nvim"
assert_link "$TEST_ROOT/wezterm.lua" "$target_home/.wezterm.lua"
assert_link "$TEST_ROOT/agterm/ghostty.conf" "$target_home/.config/agterm/ghostty.conf"
assert_link "$TEST_ROOT/agterm/keymap.conf" "$target_home/.config/agterm/keymap.conf"
assert_link "$TEST_ROOT/starship/starship.toml" "$target_home/.config/starship.toml"
[ ! -L "$target_home/.claude/CLAUDE.md" ] || \
  fail 'the dangling link to the old base prompt survived the install'
assert_file_contains "$tmp/claude.log" \
  "$target_home plugin marketplace add kalinichenko88/agent-skills"
assert_file_contains "$tmp/claude.log" \
  "$target_home plugin install kalinichenko@kalinichenko"
# Add and install are no-ops once done, so without an update `make update`
# would leave every machine on the plugin version it first installed.
assert_file_contains "$tmp/claude.log" \
  "$target_home plugin update kalinichenko@kalinichenko"
assert_link "$TEST_ROOT/claude/statusline-command.sh" \
  "$target_home/.claude/statusline-command.sh"
assert_link "$TEST_ROOT/claude/skills/create-post" "$target_home/.claude/skills/create-post"
assert_link "$TEST_ROOT/claude/hooks/check-docs-before-push.sh" \
  "$target_home/.claude/hooks/check-docs-before-push.sh"

# A renamed or deleted hook leaves a dangling link that nothing else prunes, but
# only links into this repository are ours to remove.
ln -s "$TEST_ROOT/claude/hooks/gone.sh" "$target_home/.claude/hooks/gone.sh"
ln -s "$tmp/elsewhere.sh" "$target_home/.claude/hooks/mine.sh"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config claude
[ ! -L "$target_home/.claude/hooks/gone.sh" ] || \
  fail 'a dangling link into this repository survived the install'
[ -L "$target_home/.claude/hooks/mine.sh" ] || \
  fail 'the prune removed a link this repository does not own'
assert_link "$TEST_ROOT/claude/hooks/check-docs-before-push.sh" \
  "$target_home/.claude/hooks/check-docs-before-push.sh"

# Containment, not equality: docker login writes credentials into this file.
jq -e --slurpfile source "$TEST_ROOT/docker/config.json" 'contains($source[0])' \
  "$target_home/.docker/config.json" >/dev/null || \
  fail 'Docker config merge lost the tracked keys'

jq '. + {auths: {"ghcr.io": {auth: "token"}}}' \
  "$target_home/.docker/config.json" > "$tmp/docker-with-auth.json"
mv "$tmp/docker-with-auth.json" "$target_home/.docker/config.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config docker
assert_equals 'token' \
  "$(jq -r '.auths["ghcr.io"].auth' "$target_home/.docker/config.json")"

# A plugin directory the user added sits in the same array as the tracked one.
jq '.cliPluginsExtraDirs += ["/usr/local/lib/docker/cli-plugins"]' \
  "$target_home/.docker/config.json" > "$tmp/docker-with-plugins.json"
mv "$tmp/docker-with-plugins.json" "$target_home/.docker/config.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config docker
jq -e --slurpfile source "$TEST_ROOT/docker/config.json" \
  'contains($source[0])
   and (.cliPluginsExtraDirs | index("/usr/local/lib/docker/cli-plugins") != null)' \
  "$target_home/.docker/config.json" >/dev/null || \
  fail 'Docker config merge deleted a plugin directory the user added'
# The work identity is deliberately NOT created from the example: a placeholder
# address satisfies useConfigOnly, so Git would author work commits as it
# instead of refusing. Git ignores an includeIf whose path does not exist.
[ ! -e "$target_home/.config/git/gitconfig-work" ] || \
  fail 'bootstrap must not invent a work Git identity'
[ ! -e "$target_home/.config/git/gitconfig-local" ] || \
  fail 'bootstrap must not invent a local Git config'

jq -e --slurpfile fragment "$TEST_ROOT/claude/settings-fragment.json" \
  'contains($fragment[0])' "$target_home/.claude/settings.json" \
  >/dev/null || fail 'Claude hook or status line settings were not merged'

# Add a non-hook key, then verify a second install preserves it without backups.
jq '. + {theme: "dark"}' "$target_home/.claude/settings.json" > "$tmp/settings-with-theme.json"
mv "$tmp/settings-with-theme.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config
assert_equals 'dark' "$(jq -r '.theme' "$target_home/.claude/settings.json")"
[ -z "$(find "$target_home" -name '*.backup.*' -print -quit)" ] || \
  fail 'idempotent config install created a backup'

rm "$target_home/.zshrc"
printf 'local zsh\n' > "$target_home/.zshrc"
if DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/conflict.out" 2> "$tmp/conflict.err"; then
  fail 'config conflict must fail without FORCE=1'
fi
assert_equals 'local zsh' "$(cat "$target_home/.zshrc")"

# A file bootstrap refuses to overwrite must not cost the machine every unit
# that comes after it: ssh precedes zsh, and a first run that stops there
# leaves the shell, editor and terminal unconfigured. The run reports the
# failure and still exits non-zero.
partial_home=$tmp/partial-home
mkdir -p "$partial_home/.ssh" "$partial_home/.config/git" \
  "$partial_home/.config/agterm" "$partial_home/.claude"
printf 'local ssh\n' > "$partial_home/.ssh/config"
# A refused link fails its unit even when steps after it succeed: the first of
# two rows (git, agterm), or a link before the merge and the plugin (claude).
printf 'local git\n' > "$partial_home/.config/git/config"
printf 'local ghostty\n' > "$partial_home/.config/agterm/ghostty.conf"
printf 'local statusline\n' > "$partial_home/.claude/statusline-command.sh"
if DOTFILES_TARGET_HOME="$partial_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/partial.out" 2> "$tmp/partial.err"; then
  fail 'a failed config unit must still fail the run'
fi
for unit in ssh git agterm claude; do
  assert_file_contains "$tmp/partial.err" "config $unit failed"
done
# A failed step costs the unit only that step; the ones after it still run.
assert_link "$TEST_ROOT/agterm/keymap.conf" "$partial_home/.config/agterm/keymap.conf"
jq -e --slurpfile source "$TEST_ROOT/agterm/settings.json" 'contains($source[0])' \
  "$partial_home/Library/Application Support/agterm/settings.json" >/dev/null || \
  fail 'a refused agterm link skipped the settings merge'
assert_file_contains "$tmp/claude.log" \
  "$partial_home plugin install kalinichenko@kalinichenko"

# The one exception: the plugin CLI writes the settings.json that the merge
# could not parse, so a failed merge stops the claude unit before it.
broken_home=$tmp/broken-claude-home
mkdir -p "$broken_home/.claude"
printf '{not json\n' > "$broken_home/.claude/settings.json"
if DOTFILES_TARGET_HOME="$broken_home" "$TEST_ROOT/scripts/bootstrap.sh" \
  config claude > /dev/null 2>&1; then
  fail 'a failed Claude settings merge must fail the unit'
fi
assert_equals '{not json' "$(cat "$broken_home/.claude/settings.json")"
assert_file_excludes "$tmp/claude.log" "$broken_home plugin"

# A refused gh preference fails the unit, and the keys after it still apply.
mkdir -p "$tmp/gh-fails-first"
cat > "$tmp/gh-fails-first/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$3" >> "$GH_SET_LOG"
[ "$3" != git_protocol ]
EOF
chmod +x "$tmp/gh-fails-first/gh"
if GH_SET_LOG=$tmp/gh-set.log PATH="$tmp/gh-fails-first:$PATH" \
  DOTFILES_TARGET_HOME="$tmp/gh-fail-home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config gh > /dev/null 2>&1; then
  fail 'a refused gh preference did not fail the unit'
fi
assert_equals "$(sed -n 's/:.*//p' "$TEST_ROOT/gh/config.yml")" "$(cat "$tmp/gh-set.log")"

# A project directory that cannot be created fails the unit, and the ones
# after it are still created.
mkdir -p "$tmp/dev-file-home/Dev"
printf 'not a directory\n' > "$tmp/dev-file-home/Dev/Personal"
if DOTFILES_TARGET_HOME="$tmp/dev-file-home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config dev-dirs > /dev/null 2>&1; then
  fail 'a project directory that could not be created did not fail the unit'
fi
for dir in Work 'Open Source'; do
  [ -d "$tmp/dev-file-home/Dev/$dir" ] || \
    fail "a refused project directory stopped Dev/$dir after it"
done

assert_equals 'local ssh' "$(cat "$partial_home/.ssh/config")"
assert_link "$TEST_ROOT/zsh/zshrc" "$partial_home/.zshrc"
assert_link "$TEST_ROOT/wezterm.lua" "$partial_home/.wezterm.lua"

FORCE=1 DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config
assert_link "$TEST_ROOT/zsh/zshrc" "$target_home/.zshrc"
zsh_backup=$(find "$target_home" -maxdepth 1 -name '.zshrc.backup.*' -print -quit)
[ -n "$zsh_backup" ] || fail 'forced config install did not back up .zshrc'
assert_equals 'local zsh' "$(cat "$zsh_backup")"

# A hook the user owns, on an event this repository does not declare, must keep
# firing. Demanding exact equality here would delete it to stay green.
jq '.hooks.Stop = [{hooks: [{type: "command", command: "mine"}]}]' \
  "$target_home/.claude/settings.json" > "$tmp/settings-user-hook.json"
mv "$tmp/settings-user-hook.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-user-hook.out"
assert_equals 'mine' \
  "$(jq -r '.hooks.Stop[0].hooks[0].command' "$target_home/.claude/settings.json")"
jq -e --slurpfile fragment "$TEST_ROOT/claude/settings-fragment.json" \
  '(.hooks | contains($fragment[0].hooks)) and .theme == "dark"' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude merge lost the tracked hooks or unrelated settings'

[ -z "$(find "$target_home/.claude" -maxdepth 1 -name 'settings.json.backup.*' \
  -print -quit)" ] || fail 'a no-op Claude merge created a backup'

# A hook this repository installed is replaced, not kept alongside: a copy with
# an old timeout and one whose script was renamed both give way to the tracked
# hook, and the file that gets rewritten is backed up first.
# $HOME is text in the fragment, not a shell expansion.
# shellcheck disable=SC2016
jq '.hooks.PreToolUse = [
      {matcher: "Bash", hooks: [{type: "command", timeout: 5,
        command: "$HOME/.claude/hooks/check-docs-before-push.sh"}]},
      {matcher: "Bash", hooks: [{type: "command",
        command: "$HOME/.claude/hooks/renamed-away.sh"}]}
    ]' \
  "$target_home/.claude/settings.json" > "$tmp/settings-stale-hook.json"
mv "$tmp/settings-stale-hook.json" "$target_home/.claude/settings.json"
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config \
  > "$tmp/claude-stale-hook.out"
jq -e --slurpfile fragment "$TEST_ROOT/claude/settings-fragment.json" \
  '.hooks.PreToolUse == $fragment[0].hooks.PreToolUse
   and .hooks.Stop[0].hooks[0].command == "mine"' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude merge kept a stale copy of a tracked hook'
settings_backup=$(find "$target_home/.claude" -maxdepth 1 \
  -name 'settings.json.backup.*' -print -quit)
[ -n "$settings_backup" ] || fail 'Claude merge did not back up the changed file'
assert_equals "\$HOME/.claude/hooks/renamed-away.sh" \
  "$(jq -r '.hooks.PreToolUse[1].hooks[0].command' "$settings_backup")"

# Another tool's hook on an event this repository also declares keeps firing.
# The shape is a real settings.json: a catch-all group written by another tool,
# next to the tracked one. Replacing the whole array deleted it (#37).
jq '.hooks.PreToolUse += [{matcher: "*", hooks: [{type: "command", command: "theirs", timeout: 10}]}]' \
  "$target_home/.claude/settings.json" > "$tmp/settings-shared-event.json"
mv "$tmp/settings-shared-event.json" "$target_home/.claude/settings.json"
backups_before=$(find "$target_home/.claude" -maxdepth 1 -name 'settings.json.backup.*' | wc -l)
DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config claude \
  > "$tmp/claude-shared-event.out"
jq -e --slurpfile fragment "$TEST_ROOT/claude/settings-fragment.json" \
  '(.hooks | contains($fragment[0].hooks))
   and ([.hooks.PreToolUse[].hooks[].command] | index("theirs") != null)' \
  "$target_home/.claude/settings.json" >/dev/null || \
  fail 'Claude merge deleted a hook the user owns on a tracked event'
assert_equals "$backups_before" \
  "$(find "$target_home/.claude" -maxdepth 1 -name 'settings.json.backup.*' | wc -l)"

# With several identities in play, a guessed address is worse than an error.
grep -E '^[[:space:]]*useConfigOnly[[:space:]]*=[[:space:]]*true' \
  "$TEST_ROOT/git/gitconfig" >/dev/null || \
  fail 'git must refuse to invent an author identity'
grep -E '^[[:space:]]*email[[:space:]]*=' "$TEST_ROOT/git/gitconfig" >/dev/null && \
  fail 'gitconfig must not set a top-level email; identity comes from includeIf'

# A format-tab-title handler converts every tab to Lua on each title or
# progress change; with many busy panes the GUI's main thread never idles.
grep -F 'format-tab-title' "$TEST_ROOT/wezterm.lua" >/dev/null && \
  fail 'wezterm.lua must not register a format-tab-title handler'

# Every project directory bootstrap creates must have a Git identity rule.
# Without one, commits there fall back to a guessed user@hostname address.
DRY_RUN=1 DOTFILES_TARGET_HOME="$tmp/dev-dirs" \
  "$TEST_ROOT/scripts/bootstrap.sh" config dev-dirs > "$tmp/dev-dirs.out"
project_dirs=$(sed -n 's/^info: created project directory: //p' "$tmp/dev-dirs.out")
[ -n "$project_dirs" ] || fail 'bootstrap created no project directories'
while IFS= read -r project_dir; do
  [ -n "$project_dir" ] || continue
  grep -F "gitdir:~/$project_dir/" "$TEST_ROOT/git/gitconfig" >/dev/null 2>&1 || \
    fail "no Git identity rule for $project_dir"
done <<EOF
$project_dirs
EOF

# gh owns its own config file — it writes state into it — so the preferences go
# in through `gh config set` and nothing must symlink over it.
[ -L "$target_home/.config/gh/config.yml" ] && \
  fail 'gh config must not be symlinked; gh writes to it'
grep -q 'gh config set' "$TEST_ROOT/scripts/bootstrap.sh" || \
  fail 'gh preferences are no longer applied'

# The real gh, aimed by HOME at a stand-in for the developer's home: the
# preferences belong in the target home, and a test run must not rewrite the
# developer's own gh config (#39).
command -v gh >/dev/null 2>&1 || fail 'this test needs the real gh'
env -u XDG_CONFIG_HOME -u GH_CONFIG_DIR HOME="$tmp/developer-home" \
  DOTFILES_TARGET_HOME="$tmp/gh-home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config gh > /dev/null
assert_file_contains "$tmp/gh-home/.config/gh/config.yml" 'git_protocol: ssh'
[ ! -e "$tmp/developer-home/.config/gh" ] || \
  fail 'config gh wrote outside the target home'

# The socket buffers WezTerm's mux needs are system-wide (#44): a root-owned
# LaunchDaemon re-applies them at every boot. Installed through sudo, and only
# once: an identical copy whose values are in effect means nothing to do.
daemon=launchd/dev.kalinichenko.unix-socket-buffers.plist
buffers='net.local.stream.sendspace=65536
net.local.stream.recvspace=65536'
plutil -lint "$TEST_ROOT/$daemon" >/dev/null || fail "$daemon is not a valid plist"
assert_equals "$(basename "$daemon" .plist)" \
  "$(plutil -extract Label raw -o - "$TEST_ROOT/$daemon")"
mkdir -p "$tmp/LaunchDaemons"
DOTFILES_LAUNCH_DAEMONS_DIR="$tmp/LaunchDaemons" \
  DOTFILES_TARGET_HOME="$target_home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config wezterm > /dev/null
assert_file_contains "$tmp/sudo.log" \
  "install -m 644 -o root -g wheel $TEST_ROOT/$daemon $tmp/LaunchDaemons/${daemon##*/}"
assert_file_contains "$tmp/sudo.log" \
  "launchctl bootstrap system $tmp/LaunchDaemons/${daemon##*/}"
cp "$TEST_ROOT/$daemon" "$tmp/LaunchDaemons/"
: > "$tmp/sudo.log"
DOTFILES_LAUNCH_DAEMONS_DIR="$tmp/LaunchDaemons" SYSCTL_STUB_VALUES=$buffers \
  DOTFILES_TARGET_HOME="$target_home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config wezterm > /dev/null
[ ! -s "$tmp/sudo.log" ] || \
  fail "an installed launch daemon was installed again: $(cat "$tmp/sudo.log")"

# The copy went in and the load failed (#52): the next run must load it again,
# not stop at the identical copy while the buffers stay at the 8 KB default.
DOTFILES_LAUNCH_DAEMONS_DIR="$tmp/LaunchDaemons" \
  SYSCTL_STUB_VALUES=${buffers//=65536/=8192} \
  DOTFILES_TARGET_HOME="$target_home" \
  "$TEST_ROOT/scripts/bootstrap.sh" config wezterm > /dev/null
assert_file_contains "$tmp/sudo.log" \
  "launchctl bootstrap system $tmp/LaunchDaemons/${daemon##*/}"

# Both scripts now read setup/links.tsv, so there is no second table to drift
# against; what has to hold is that every row actually got installed.
while IFS=$'\t' read -r _ source target; do
  assert_link "$TEST_ROOT/$source" "$target_home/$target"
done < <(awk -F '\t' 'NF && $1 !~ /^#/ { print $2 "\t" $3 "\t" $4 }' \
  "$TEST_ROOT/setup/links.tsv")

pass 'configuration installation is complete, safe, and idempotent'
