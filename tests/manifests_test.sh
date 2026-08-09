#!/bin/bash

set -eu

# The helper path is resolved from this script at runtime.
# shellcheck disable=SC1091
. "$(dirname "$0")/test_helper.sh"

for value in \
  'cask "1password-cli"' \
  'brew "yt-dlp"' \
  'cask "codexbar"' \
  'cask "wezterm@nightly"' \
  'cask "umputun/apps/agterm"' \
  'brew "bun"' \
  'cask "handy"' \
  'brew "poppler"' \
  'brew "sox"' \
  'brew "tree-sitter-cli"' \
  'brew "gitleaks"' \
  'brew "jq"'; do
  assert_file_contains "$TEST_ROOT/Brewfile" "$value"
done

for value in \
  'brew "whisper-cpp"' \
  'brew "tree-sitter"' \
  'cask "ghostty"' \
  'cask "screenize"' \
  'cask "kap"' \
  'cask "font-fira-code"' \
  'cask "font-iosevka"' \
  'tap "steipete/tap"' \
  'tap "thedavidweng/tap"' \
  'cask "perplexity"'; do
  assert_file_excludes "$TEST_ROOT/Brewfile" "$value"
done

# This repository is public: machine-specific software belongs in the gitignored
# .local manifests, never in the tracked baseline.
for token in base lunar plex-media-server qmk-toolbox skim steam tor-browser \
  transmission vlc whatsapp zotero; do
  assert_file_excludes "$TEST_ROOT/Brewfile" "cask \"$token\""
  assert_file_excludes "$TEST_ROOT/setup/cask-apps.tsv" "$token	/Applications/"
done

if grep -q '^app	' "$TEST_ROOT/setup/manual-checks.tsv"; then
  fail 'tracked manual-checks.tsv must not enumerate installed applications'
fi
for local_manifest in Brewfile.local setup/cask-apps.local.tsv \
  setup/manual-checks.local.tsv; do
  if git -C "$TEST_ROOT" ls-files --error-unmatch "$local_manifest" \
    >/dev/null 2>&1; then
    fail "$local_manifest must stay untracked"
  fi
done

node_versions=$(grep -Ev '^[[:space:]]*(#|$)' "$TEST_ROOT/setup/node-versions.txt")
assert_equals 'v24.18.0' "$node_versions"
assert_file_contains "$TEST_ROOT/setup/uv-tools.txt" 'mcp-telegram==0.1.2'
assert_file_contains "$TEST_ROOT/setup/uv-tools.txt" 'specify-cli==0.8.4'

awk -F '\t' 'NF && $1 !~ /^#/ && NF != 2 { exit 1 }' \
  "$TEST_ROOT/setup/cask-apps.tsv" || fail 'invalid cask-apps.tsv'
awk -F '\t' 'NF && $1 !~ /^#/ && NF != 3 { exit 1 }' \
  "$TEST_ROOT/setup/manual-checks.tsv" || fail 'invalid manual-checks.tsv'

pass 'curated manifests match the approved baseline'
