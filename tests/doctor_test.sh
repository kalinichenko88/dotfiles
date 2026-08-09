#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"
export DOTFILES_HOMEBREW_BIN="$TEST_ROOT/tests/fixtures/bin/brew"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
target_home=$tmp/home
apps_root=$tmp/apps-root
stub_bin=$tmp/bin
mkdir -p "$target_home/.nvm/versions/node/v24.18.0" \
  "$target_home/.nvm/alias" "$apps_root/Applications/Obsidian.app" "$stub_bin" \
  "$tmp/doctor-tmp"
export TMPDIR=$tmp/doctor-tmp/
printf 'v24.18.0\n' > "$target_home/.nvm/alias/default"

for command_name in claude opencode lms op codex; do
  ln -s /usr/bin/true "$stub_bin/$command_name"
done

DOTFILES_TARGET_HOME="$target_home" "$TEST_ROOT/scripts/bootstrap.sh" config >/dev/null

# Bootstrap must not have invented a work identity; the rest of the run needs a
# real one so the warning does not muddy the other assertions.
[ ! -e "$target_home/.config/git/gitconfig-work" ] || \
  fail 'bootstrap created a work Git identity'
printf '[user]\n    email = person@example.test\n' \
  > "$target_home/.config/git/gitconfig-work"

# Doctor verifies the shared baseline plus the optional machine-local manifest,
# so the stub state has to cover both.
manifest() {
  cat "$TEST_ROOT/Brewfile"
  [ -f "$TEST_ROOT/Brewfile.local" ] && cat "$TEST_ROOT/Brewfile.local"
  return 0
}

brew_formulae=$(manifest | awk 'match($0, /^brew "[^"]+"/) {
  value=substr($0, RSTART + 6, RLENGTH - 7)
  sub(/^.*\//, "", value)
  print value
}')
brew_casks=$(manifest | awk 'match($0, /^cask "[^"]+"/) {
  value=substr($0, RSTART + 6, RLENGTH - 7)
  sub(/^.*\//, "", value)
  if (value != "obsidian") print value
}')
brew_taps=$(manifest | awk 'match($0, /^tap "[^"]+"/) {
  print substr($0, RSTART + 5, RLENGTH - 6)
}')

# gh preferences are read back through `gh config get`, so the stub answers
# from the same file bootstrap applies.
gh_preferences=$(sed -n 's/^\([a-z_]*\): \(.*\)$/\1=\2/p' "$TEST_ROOT/gh/config.yml")

doctor_path="$TEST_ROOT/tests/fixtures/bin:$stub_bin:/usr/bin:/bin"

# Every invocation shares the same stub environment; a caller overrides one
# piece of it by setting STUB_* in front of the call.
run_doctor() {
  BREW_STUB_FORMULAE="${STUB_FORMULAE-$brew_formulae}" \
  BREW_STUB_CASKS="$brew_casks" BREW_STUB_TAPS="${STUB_TAPS-$brew_taps}" \
  BREW_STUB_OUTDATED="${STUB_OUTDATED-}" \
  GH_STUB_CONFIG="${STUB_GH_CONFIG-$gh_preferences}" \
  NPM_STUB_SLEEP="${STUB_NPM_SLEEP-0}" \
  DOCTOR_AUTH_TIMEOUT_SECONDS="${STUB_AUTH_TIMEOUT-3}" \
  UV_STUB_TOOLS="$(grep -Ev '^[[:space:]]*(#|$)' "$TEST_ROOT/setup/uv-tools.txt" \
    | sed 's/==/ v/' || :)" \
  PATH="$doctor_path" DOTFILES_TARGET_HOME="$target_home" \
  DOTFILES_APPLICATIONS_ROOT="$apps_root" \
  "$TEST_ROOT/scripts/doctor.sh"
}

if run_doctor > "$tmp/empty-node.out"; then
  fail 'doctor must reject an empty expected Node directory'
fi
assert_file_contains "$tmp/empty-node.out" 'missing node v24.18.0'

mkdir -p "$target_home/.nvm/versions/node/v24.18.0/bin"
printf '#!/bin/sh\nprintf "v24.18.0\\n"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"
chmod +x "$target_home/.nvm/versions/node/v24.18.0/bin/node"

started_at=$SECONDS
STUB_OUTDATED=fd STUB_NPM_SLEEP=5 STUB_AUTH_TIMEOUT=1 \
  run_doctor > "$tmp/ready.out"
elapsed=$((SECONDS - started_at))
[ "$elapsed" -lt 4 ] || fail 'doctor did not time out a hanging auth probe'

assert_file_contains "$tmp/ready.out" 'present-manual cask obsidian'
# A cask installed by hand must not be re-failed by a second, stricter pass.
assert_file_excludes "$tmp/ready.out" 'missing brew-bundle'
assert_file_excludes "$tmp/ready.out" 'missing manual-command'
assert_file_contains "$tmp/ready.out" 'warning outdated fd'
assert_file_contains "$tmp/ready.out" 'needs-login auth GitHub CLI'
assert_file_excludes "$tmp/ready.out" 'AUTH_SECRET_SENTINEL'
assert_file_excludes "$tmp/ready.out" 'NPM_AUTH_SECRET_SENTINEL'
assert_file_excludes "$tmp/ready.out" 'cask openclaw'
assert_file_excludes "$tmp/ready.out" 'manual-command OpenClaw CLI'
for removed_cask in perplexity zcode buzz; do
  assert_file_excludes "$tmp/ready.out" "cask $removed_cask"
done
# Machine-specific software must not reach the shared baseline.
for local_cask in steam plex-media-server tor-browser qmk-toolbox; do
  assert_file_excludes "$TEST_ROOT/Brewfile" "cask \"$local_cask\""
done

# A gh preference that drifted from the tracked file is a required failure.
if STUB_GH_CONFIG='git_protocol=https' run_doctor > "$tmp/gh-drift.out"; then
  fail 'a drifted gh preference must fail doctor'
fi
assert_file_contains "$tmp/gh-drift.out" 'missing config gh-git_protocol'

# An absent work identity is safe — useConfigOnly refuses the commit — but an
# unedited copy of the example is not: the placeholder satisfies it.
mv "$target_home/.config/git/gitconfig-work" "$tmp/work-identity"
run_doctor > "$tmp/no-work.out" || \
  fail 'an absent work identity must not fail doctor'
assert_file_contains "$tmp/no-work.out" 'warning config git-work-email'
cp "$TEST_ROOT/git/gitconfig-work.example" \
  "$target_home/.config/git/gitconfig-work"
if run_doctor > "$tmp/placeholder-work.out"; then
  fail 'an unedited work-email placeholder must fail doctor'
fi
assert_file_contains "$tmp/placeholder-work.out" 'missing config git-work-email'
mv "$tmp/work-identity" "$target_home/.config/git/gitconfig-work"

# A CLI with its own installer is not present right after bootstrap, so its
# absence must stay a warning — otherwise a first run can never finish.
unlink "$stub_bin/lms"
run_doctor > "$tmp/uninstalled-cli.out" || \
  fail 'a not-yet-installed manual CLI must not fail doctor'
assert_file_contains "$tmp/uninstalled-cli.out" 'warning manual-command LM Studio CLI'
ln -s /usr/bin/true "$stub_bin/lms"

printf '#!/bin/sh\nprintf "v24.17.0\\n"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"
if run_doctor > "$tmp/mismatched-node.out"; then
  fail 'doctor must reject a mismatched Node version binary'
fi
assert_file_contains "$tmp/mismatched-node.out" 'missing node v24.18.0'

printf '#!/bin/sh\nprintf "v24.18.0\\n\\n"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"
if run_doctor > "$tmp/extra-node-output.out"; then
  fail 'doctor must reject extra Node version output'
fi
assert_file_contains "$tmp/extra-node-output.out" 'missing node v24.18.0'

printf '#!/bin/sh\nprintf "v24.18.0\\000\\n"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"
if run_doctor > "$tmp/nul-node-output.out"; then
  fail 'doctor must reject Node version output containing a NUL byte'
fi
assert_file_contains "$tmp/nul-node-output.out" 'missing node v24.18.0'

printf '#!/bin/sh\nprintf "v24.18.0"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"
if run_doctor > "$tmp/unterminated-node-output.out"; then
  fail 'doctor must reject unterminated Node version output'
fi
assert_file_contains "$tmp/unterminated-node-output.out" 'missing node v24.18.0'

printf '#!/bin/sh\nprintf "v24.18.0\\n"\n' > \
  "$target_home/.nvm/versions/node/v24.18.0/bin/node"

unlink "$stub_bin/opencode"
printf '#!/bin/sh\nexit 1\n' > "$stub_bin/opencode"
chmod +x "$stub_bin/opencode"
if run_doctor > "$tmp/probe.out"; then
  fail 'doctor must fail when a present manual command fails its probe'
fi
assert_file_contains "$tmp/probe.out" 'probe-failed manual-command OpenCode'
unlink "$stub_bin/opencode"
ln -s /usr/bin/true "$stub_bin/opencode"

if STUB_FORMULAE=$(printf '%s\n' "$brew_formulae" | grep -v '^gitleaks$') \
  run_doctor > "$tmp/missing.out"; then
  fail 'doctor must fail when a required formula is missing'
fi
assert_file_contains "$tmp/missing.out" 'missing formula gitleaks'

if STUB_TAPS=$(printf '%s\n' "$brew_taps" | grep -v '^stripe/stripe-cli$') \
  run_doctor > "$tmp/tap.out"; then
  fail 'doctor must fail when a required tap is missing'
fi
assert_file_contains "$tmp/tap.out" 'missing tap stripe/stripe-cli'

printf 'v22.23.1\n' > "$target_home/.nvm/alias/default"
if run_doctor > "$tmp/node.out"; then
  fail 'doctor must fail when the NVM default does not match the exact pin'
fi
assert_file_contains "$tmp/node.out" 'missing node-default v24.18.0'

printf 'v24.18.0\n' > "$target_home/.nvm/alias/default"
mkdir -p "$target_home/.config/dotfiles"
printf 'verified\n' > "$target_home/.config/dotfiles/bootstrap-complete"
# The completion marker used to switch on a second `brew bundle check` pass
# that re-failed every present-manual cask. It must stay gone.
run_doctor > "$tmp/marked.out" || \
  fail 'the completion marker must not make a hand-installed cask fail doctor'
assert_file_contains "$tmp/marked.out" 'present-manual cask obsidian'
assert_file_excludes "$tmp/marked.out" 'brew-bundle'

[ -z "$(find "$tmp/doctor-tmp" -mindepth 1 -print -quit)" ] || \
  fail 'doctor temporary directories were not removed'

pass 'doctor distinguishes required failures from warnings and manual state'
