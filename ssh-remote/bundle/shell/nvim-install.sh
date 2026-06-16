# POSIX helpers to provide nvim on the remote: prefer system nvim, then a cached
# download under $_st/bin, else download a pinned, checksum-verified official
# tarball. Sourced by bootstrap.sh and unit-tested offline (the _dfr_uname_m and
# _dfr_fetch seams are overridable). Requires in env: DOTFILES_REMOTE (bundle dir
# holding nvim-release.env) and _st (writable state dir).
# shellcheck shell=sh
# shellcheck disable=SC2154  # _st and DOTFILES_REMOTE are caller-provided (sourced helper)

_dfr_uname_m() { uname -m; }

# _dfr_fetch <url> <out-file> -> 0 on success (curl then wget).
_dfr_fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    printf 'ssh-remote: no curl/wget to download nvim\n' >&2
    return 1
  fi
}

# _dfr_sha256 <file> -> prints hex digest; returns 1 if no tool available.
_dfr_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    _h=$(sha256sum "$1") && printf '%s' "${_h%% *}"
  elif command -v shasum >/dev/null 2>&1; then
    _h=$(shasum -a 256 "$1") && printf '%s' "${_h%% *}"
  else return 1; fi
}

# Download + verify + extract the pinned nvim into $_st; symlink $_st/bin/nvim.
# Returns 0 on success (binary present at the symlink), 1 otherwise.
_dfr_download_nvim() {
  [ -n "$_st" ] || return 1
  _rel="$DOTFILES_REMOTE/nvim-release.env"
  [ -r "$_rel" ] || return 1
  # shellcheck source=/dev/null
  . "$_rel"

  _arch="$(_dfr_uname_m)"
  case "$_arch" in
    x86_64|amd64)  _a=x86_64; _sha="$DFR_NVIM_SHA256_x86_64" ;;
    aarch64|arm64) _a=arm64;  _sha="$DFR_NVIM_SHA256_arm64" ;;
    *) printf 'ssh-remote: no prebuilt nvim for %s\n' "$_arch" >&2; return 1 ;;
  esac

  _asset="nvim-linux-$_a.tar.gz"
  _url="https://github.com/neovim/neovim/releases/download/$DFR_NVIM_VERSION/$_asset"
  mkdir -p "$_st/bin" 2>/dev/null
  _tmp="$_st/.nvim-dl.$$"

  printf 'ssh-remote: fetching nvim %s (%s)...\n' "$DFR_NVIM_VERSION" "$_a" >&2
  _dfr_fetch "$_url" "$_tmp" || { rm -f "$_tmp"; return 1; }

  _got="$(_dfr_sha256 "$_tmp")" || {
    printf 'ssh-remote: no sha256 tool; refusing unverified nvim\n' >&2; rm -f "$_tmp"; return 1; }
  if [ "$_got" != "$_sha" ]; then
    printf 'ssh-remote: nvim checksum mismatch (got %s)\n' "$_got" >&2; rm -f "$_tmp"; return 1
  fi

  rm -rf "$_st"/nvim-linux-* 2>/dev/null
  ( cd "$_st" && tar -xzf "$_tmp" ) || { rm -f "$_tmp"; return 1; }
  rm -f "$_tmp"

  _bin="$(find "$_st" -maxdepth 3 -type f -name nvim -path '*/bin/nvim' 2>/dev/null | head -n1)"
  [ -n "$_bin" ] || return 1
  ln -sf "$_bin" "$_st/bin/nvim"
  return 0
}

# Echo a usable nvim invocation (system name 'nvim', or a cached/downloaded path),
# or nothing if none can be provided. Return 0 if something was echoed.
_dfr_resolve_nvim() {
  if command -v nvim >/dev/null 2>&1; then printf 'nvim'; return 0; fi
  if [ -x "$_st/bin/nvim" ] && "$_st/bin/nvim" --version >/dev/null 2>&1; then
    printf '%s' "$_st/bin/nvim"; return 0
  fi
  if _dfr_download_nvim && [ -x "$_st/bin/nvim" ] && "$_st/bin/nvim" --version >/dev/null 2>&1; then
    printf '%s' "$_st/bin/nvim"; return 0
  fi
  return 1
}
