#!/bin/sh
# Offline unit tests for nvim-install.sh: arch mapping, checksum gate, extraction.
# No network: _dfr_fetch is stubbed to copy a local fake tarball, _dfr_uname_m is
# stubbed per case. The run-check (nvim --version) lives in _dfr_resolve_nvim and is
# NOT exercised here (the real download is a Linux binary; this box may be macOS).
# shellcheck shell=sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/../bundle/shell/nvim-install.sh"
fails=0
ok() { if [ "$2" = "$3" ]; then printf 'PASS %s\n' "$1"; else printf 'FAIL %s: want [%s] got [%s]\n' "$1" "$3" "$2"; fails=$((fails+1)); fi; }

# Fake nvim tarball whose top dir matches the asset naming.
mk_fixture() { # $1=arch -> path to .tar.gz containing nvim-linux-<arch>/bin/nvim
  d=$(mktemp -d); mkdir -p "$d/nvim-linux-$1/bin"
  printf '#!/bin/sh\necho fake-nvim\n' > "$d/nvim-linux-$1/bin/nvim"; chmod +x "$d/nvim-linux-$1/bin/nvim"
  ( cd "$d" && tar -czf fixture.tgz "nvim-linux-$1" ); printf '%s' "$d/fixture.tgz"
}

FX="$(mk_fixture x86_64)"; FX_SHA="$(_dfr_sha256 "$FX")"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_fetch() { cp "$FX" "$2"; }   # stub network for all cases

# Case 1: x86_64 + matching checksum -> success, symlink created
TMPB=$(mktemp -d); printf 'DFR_NVIM_VERSION=v0-test\nDFR_NVIM_SHA256_x86_64=%s\nDFR_NVIM_SHA256_arm64=x\n' "$FX_SHA" > "$TMPB/nvim-release.env"
# shellcheck disable=SC2034  # DOTFILES_REMOTE used by sourced nvim-install.sh functions
DOTFILES_REMOTE="$TMPB"; _st="$(mktemp -d)"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_uname_m() { echo x86_64; }
_dfr_download_nvim; rc=$?
ok "x86_64 good-sum returns 0" "$rc" 0
[ -x "$_st/bin/nvim" ] && have=yes || have=no
ok "x86_64 symlink present" "$have" yes
ok "x86_64 symlink target" "$(readlink "$_st/bin/nvim")" "$_st/nvim-linux-x86_64/bin/nvim"

# Case 2: checksum mismatch -> failure, no symlink
TMPB=$(mktemp -d); printf 'DFR_NVIM_VERSION=v0-test\nDFR_NVIM_SHA256_x86_64=deadbeef\nDFR_NVIM_SHA256_arm64=x\n' > "$TMPB/nvim-release.env"
# shellcheck disable=SC2034  # DOTFILES_REMOTE used by sourced nvim-install.sh functions
DOTFILES_REMOTE="$TMPB"; _st="$(mktemp -d)"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_uname_m() { echo x86_64; }
_dfr_download_nvim 2>/dev/null; rc=$?
ok "bad-sum returns 1" "$rc" 1
[ -e "$_st/bin/nvim" ] && have=yes || have=no
ok "bad-sum no symlink" "$have" no

# Case 3: unsupported arch -> failure
TMPB=$(mktemp -d); printf 'DFR_NVIM_VERSION=v0-test\nDFR_NVIM_SHA256_x86_64=%s\nDFR_NVIM_SHA256_arm64=x\n' "$FX_SHA" > "$TMPB/nvim-release.env"
# shellcheck disable=SC2034  # DOTFILES_REMOTE used by sourced nvim-install.sh functions
DOTFILES_REMOTE="$TMPB"; _st="$(mktemp -d)"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_uname_m() { echo ppc64; }
_dfr_download_nvim 2>/dev/null; rc=$?
ok "unsupported arch returns 1" "$rc" 1

# Case 4: aarch64 -> arm64 asset + matching checksum -> success
FX2="$(mk_fixture arm64)"; FX2_SHA="$(_dfr_sha256 "$FX2")"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_fetch() { cp "$FX2" "$2"; }
TMPB=$(mktemp -d); printf 'DFR_NVIM_VERSION=v0-test\nDFR_NVIM_SHA256_x86_64=x\nDFR_NVIM_SHA256_arm64=%s\n' "$FX2_SHA" > "$TMPB/nvim-release.env"
# shellcheck disable=SC2034  # DOTFILES_REMOTE used by sourced nvim-install.sh functions
DOTFILES_REMOTE="$TMPB"; _st="$(mktemp -d)"
# shellcheck disable=SC2329  # redefined as stub; invoked indirectly by _dfr_download_nvim
_dfr_uname_m() { echo aarch64; }
_dfr_download_nvim; rc=$?
ok "arm64 good-sum returns 0" "$rc" 0
[ -x "$_st/bin/nvim" ] && have=yes || have=no
ok "arm64 symlink present" "$have" yes
ok "arm64 symlink target" "$(readlink "$_st/bin/nvim")" "$_st/nvim-linux-arm64/bin/nvim"

[ "$fails" -eq 0 ] || { printf '%d failures\n' "$fails"; exit 1; }
printf 'all nvim-install tests passed\n'
