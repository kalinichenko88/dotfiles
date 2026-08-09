# SSH Remote nvim + prompt + wezterm title — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Typing `ssh <host>` ships a portable, zero-dependency nvim + a "remote" shell prompt to the server, sets the wezterm tab title to the host, and restores everything on exit — with no permanent server changes.

**Architecture:** A zsh `ssh()` wrapper intercepts only the bare `ssh [user@]host` form (config-probed for plain login), opens one shared ControlMaster connection, rsyncs a self-contained bundle to `~/.dotfiles-remote/bundle/`, then launches a remote shell wired (via `ZDOTDIR`/`--init-file` trampolines) to our prompt and an XDG-isolated nvim. Anything non-trivial passes straight through to `command ssh`.

**Tech Stack:** zsh + POSIX sh, OpenSSH (ControlMaster, `ssh -G`), rsync (openrsync-compatible) with tar fallback, Neovim native `pack/` packages + mini.nvim, wezterm Lua (`format-tab-title` + user-vars), GNU Make.

**Spec:** `docs/superpowers/specs/2026-06-15-ssh-remote-nvim-design.md` (read it first).

**Conventions:** All new shell identifiers are namespaced `_dfr_` / `_DFR_` / `DOTFILES_REMOTE*`. Match the existing Makefile style (`→`/`✓` echoes, `.PHONY`, `$(PWD)` paths).

---

## File Structure

**Create:**
- `ssh-remote/plugins.txt` — tracked vendoring manifest (`<name> <git-url> <commit-sha>`).
- `ssh-remote/bundle/bootstrap.sh` — remote entrypoint (POSIX sh, tracked +x).
- `ssh-remote/bundle/zdotdir/.zshenv` `.zprofile` `.zshrc` `.zlogin` — zsh trampolines.
- `ssh-remote/bundle/bashrc` — bash trampoline.
- `ssh-remote/bundle/shell/profile-select.sh` — POSIX login-profile selection (testable).
- `ssh-remote/bundle/shell/prompt.zsh` `prompt.sh` — remote prompt indicators.
- `ssh-remote/bundle/xdg/config/nvim/init.lua` — portable nvim config.
- `ssh-remote/bundle/xdg/config/nvim/pack/plugins/start/` — vendored plugins (gitignored).
- `zsh/ssh-remote.zsh` — the `ssh()` wrapper + pure helpers (auto-sourced).
- `ssh-remote/tests/test-guard.zsh` — unit tests for arg-parse + config-probe.
- `ssh-remote/tests/test-profile-select.sh` — unit test for bash profile selection.
- `ssh-remote/tests/fixtures/` — `ssh -G` fixture outputs.

**Modify:**
- `.gitignore` — ignore the vendored `pack/`.
- `Makefile` — add `ssh-remote-vendor` / `ssh-remote-install` / `ssh-remote-test` / `ssh-remote-clean-host`.
- `wezterm.lua` — `format-tab-title` prefers `user_vars.ssh_host`.
- `CLAUDE.md`, `README.md` — document the feature.

**Prereqs (verify once at start):**
- [ ] `command -v nvim shellcheck rsync zsh` — if `shellcheck` is missing, `brew install shellcheck`. nvim/rsync/zsh already present on this machine.

---

## Task 1: Scaffolding — manifest, gitignore, Make targets, vendored plugins

**Files:**
- Create: `ssh-remote/plugins.txt`
- Modify: `.gitignore`, `Makefile`

- [ ] **Step 1: Create the vendoring manifest**

Create `ssh-remote/plugins.txt` (pin to a real commit — resolve the current `main` SHA in Step 4):

```
# <name> <git-url> <commit-sha>   — vendored into bundle/.../pack/plugins/start/<name>
# mini.nvim ships both the plugin modules AND colorschemes (minischeme), so it is the
# only dependency. Pin the SHA; `make ssh-remote-vendor` checks it out and strips .git.
mini.nvim https://github.com/echasnovski/mini.nvim PLACEHOLDER_SHA
```

- [ ] **Step 2: Ignore the vendored plugins**

Add to `.gitignore` (append after the existing `zsh/local.zsh` block):

```
# Vendored remote nvim plugins (populated by `make ssh-remote-vendor`)
ssh-remote/bundle/xdg/config/nvim/pack/
```

- [ ] **Step 3: Add Make targets**

Append to `Makefile`, and add the four target names to the `.PHONY` line:

```make
ssh-remote-vendor:
	@echo "→ Vendoring remote nvim plugins from ssh-remote/plugins.txt"
	@dest="$(PWD)/ssh-remote/bundle/xdg/config/nvim/pack/plugins/start"; \
	mkdir -p "$$dest"; \
	grep -vE '^[[:space:]]*(#|$$)' $(PWD)/ssh-remote/plugins.txt | while read -r name url sha; do \
		d="$$dest/$$name"; \
		if [ ! -d "$$d/.git" ] && [ ! -d "$$d" ]; then git clone --quiet "$$url" "$$d"; fi; \
		if [ -d "$$d/.git" ]; then git -C "$$d" fetch --quiet --all; fi; \
		if [ ! -d "$$d/.git" ]; then git -C "$$d" init --quiet && git -C "$$d" remote add origin "$$url" 2>/dev/null; git -C "$$d" fetch --quiet origin; fi; \
		git -C "$$d" checkout --quiet "$$sha"; \
		rm -rf "$$d/.git"; \
		echo "  ✓ $$name @ $$sha"; \
	done
	@echo "✓ Remote nvim plugins vendored"

ssh-remote-install: ssh-remote-vendor
	@echo "→ Installing ssh-remote (wrapper auto-sourced via zsh/*.zsh)"
	@chmod +x $(PWD)/ssh-remote/bundle/bootstrap.sh
	@git -C $(PWD) update-index --chmod=+x ssh-remote/bundle/bootstrap.sh 2>/dev/null || true
	@test -d $(PWD)/ssh-remote/bundle/xdg/config/nvim/pack/plugins/start/mini.nvim \
		|| { echo "✗ plugins not vendored — run 'make ssh-remote-vendor'"; exit 1; }
	@echo "✓ ssh-remote installed — run 'reload' (or open a new shell)"

ssh-remote-test:
	@echo "→ Running ssh-remote tests"
	@zsh $(PWD)/ssh-remote/tests/test-guard.zsh
	@sh  $(PWD)/ssh-remote/tests/test-profile-select.sh
	@XDG_CONFIG_HOME="$(PWD)/ssh-remote/bundle/xdg/config" \
		XDG_DATA_HOME="$$(mktemp -d)" XDG_STATE_HOME="$$(mktemp -d)" \
		XDG_CACHE_HOME="$$(mktemp -d)" \
		nvim --headless +'lua assert(vim.g.mapleader==" "); assert((require("mini.statusline")) ~= nil); io.write("nvim-ok\n")' +q
	@echo "✓ ssh-remote tests passed"

ssh-remote-clean-host:
	@test -n "$(HOST)" || { echo "usage: make ssh-remote-clean-host HOST=<ssh-host>"; exit 1; }
	@echo "→ Removing ~/.dotfiles-remote on $(HOST)"
	@ssh "$(HOST)" 'rm -rf ~/.dotfiles-remote'
	@echo "✓ cleaned $(HOST)"
```

- [ ] **Step 4: Resolve and pin the mini.nvim SHA, then vendor**

Run:
```bash
SHA=$(git ls-remote https://github.com/echasnovski/mini.nvim main | cut -f1)
sed -i '' "s/PLACEHOLDER_SHA/$SHA/" ssh-remote/plugins.txt
make ssh-remote-vendor
```
Expected: `✓ mini.nvim @ <sha>` and `ssh-remote/bundle/xdg/config/nvim/pack/plugins/start/mini.nvim/lua/mini/` exists with **no** `.git` dir.

- [ ] **Step 5: Verify gitignore hides the vendored tree**

Run: `git status --porcelain ssh-remote/bundle/xdg/config/nvim/pack/`
Expected: empty output (pack is ignored).

- [ ] **Step 6: Commit**

```bash
git add ssh-remote/plugins.txt .gitignore Makefile
git commit -m "feat(ssh-remote): scaffold manifest, make targets, gitignore vendored plugins"
```

---

## Task 2: Portable nvim config

**Files:**
- Create: `ssh-remote/bundle/xdg/config/nvim/init.lua`

- [ ] **Step 1: Write the headless smoke test (run before the file exists → fails)**

Run (no init.lua yet):
```bash
XDG_CONFIG_HOME="$PWD/ssh-remote/bundle/xdg/config" \
XDG_DATA_HOME="$(mktemp -d)" XDG_STATE_HOME="$(mktemp -d)" XDG_CACHE_HOME="$(mktemp -d)" \
nvim --headless +'lua assert(vim.g.mapleader==" "); io.write("ok\n")' +q
```
Expected: FAIL — `vim.g.mapleader` is `nil` (assertion error), because there is no config.

- [ ] **Step 2: Write `init.lua`**

Create `ssh-remote/bundle/xdg/config/nvim/init.lua`:

```lua
-- Portable remote nvim: zero external deps, vendored plugins via native packages.
-- Launched with isolated XDG dirs (config here in the synced bundle; data/state/
-- cache under ~/.dotfiles-remote/state). See bundle/bootstrap.sh.

-- stdpath('config') == $XDG_CONFIG_HOME/nvim == this directory. Prepend it to
-- packpath so pack/plugins/start/* is discoverable, then packadd immediately
-- (native start packages are otherwise sourced AFTER init.lua, so a bare
-- `require` here would fail).
local here = vim.fn.stdpath('config')
vim.opt.packpath:prepend(here)
pcall(vim.cmd.packadd, 'mini.nvim')

-- Leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Options (server-appropriate). clipboard is intentionally NOT set to
-- unnamedplus: servers usually lack a clipboard provider.
local o = vim.opt
o.number = true
o.signcolumn = 'yes'
o.termguicolors = true
o.cursorline = true
o.mouse = 'a'
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.smartindent = true
o.wrap = false
o.scrolloff = 8
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.hidden = true
o.swapfile = false
o.undofile = true

-- Colorscheme shipped by mini.nvim. pcall so a rename never aborts startup.
pcall(vim.cmd.colorscheme, 'minischeme')

-- mini.nvim modules (each guarded; a missing module never aborts startup)
local function setup(mod, opts)
  local ok, m = pcall(require, mod)
  if ok then pcall(m.setup, opts or {}) end
  return ok
end
setup('mini.statusline')
setup('mini.surround')
setup('mini.comment')
setup('mini.pairs')
local has_files = setup('mini.files')
local has_pick = setup('mini.pick')

-- Keymaps
local map = vim.keymap.set
map('n', '<Esc>', '<cmd>noh<cr>', { desc = 'Clear search highlight' })
map('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save file' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
map('n', '<A-j>', '<cmd>m .+1<cr>==', { desc = 'Move line down' })
map('n', '<A-k>', '<cmd>m .-2<cr>==', { desc = 'Move line up' })
map('v', '<A-j>', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
map('v', '<A-k>', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

if has_files then
  map('n', '<leader>e', function() require('mini.files').open() end, { desc = 'File explorer' })
end

if has_pick then
  map('n', '<leader>ff', '<cmd>Pick files<cr>', { desc = 'Find files' })
  map('n', '<leader>fb', '<cmd>Pick buffers<cr>', { desc = 'Buffers' })
  -- mini.pick: files()/grep() fall back to pure-Lua, but grep_live() THROWS an
  -- error with no rg/git. Map grep_live only when a CLI grep tool exists.
  if vim.fn.executable('rg') == 1 or vim.fn.executable('git') == 1 then
    map('n', '<leader>fg', '<cmd>Pick grep_live<cr>', { desc = 'Live grep' })
  else
    map('n', '<leader>fg', '<cmd>Pick grep<cr>', { desc = 'Grep (slow Lua fallback)' })
    vim.schedule(function()
      vim.notify('ssh-remote nvim: no rg/git — live grep disabled', vim.log.levels.WARN)
    end)
  end
end
```

- [ ] **Step 3: Run the smoke test (now passes)**

Run:
```bash
XDG_CONFIG_HOME="$PWD/ssh-remote/bundle/xdg/config" \
XDG_DATA_HOME="$(mktemp -d)" XDG_STATE_HOME="$(mktemp -d)" XDG_CACHE_HOME="$(mktemp -d)" \
nvim --headless +'lua assert(vim.g.mapleader==" "); assert((require("mini.statusline")) ~= nil); io.write("ok\n")' +q
```
Expected: prints `ok`, exit 0. (Requires Task 1 vendoring done.)

- [ ] **Step 4: Verify state isolation — no writes to standard XDG**

Run:
```bash
tmp=$(mktemp -d)
XDG_CONFIG_HOME="$PWD/ssh-remote/bundle/xdg/config" \
XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
nvim --headless +'wq! '"$tmp/probe.txt" >/dev/null 2>&1
find "$tmp" -name '*.shada' -o -name 'undo' -type d | head
```
Expected: shada/undo land under `$tmp/...`, confirming writes stay in the isolated dirs.

- [ ] **Step 5: Commit**

```bash
git add ssh-remote/bundle/xdg/config/nvim/init.lua
git commit -m "feat(ssh-remote): portable zero-dep nvim config with mini.nvim"
```

---

## Task 3: Login-profile selection helper + unit test (TDD)

**Files:**
- Create: `ssh-remote/bundle/shell/profile-select.sh`, `ssh-remote/tests/test-profile-select.sh`

- [ ] **Step 1: Write the failing test**

Create `ssh-remote/tests/test-profile-select.sh`:

```sh
#!/bin/sh
# Unit-test the deterministic login-profile selection (POSIX).
set -u
SELECT="$(CDPATH= cd "$(dirname "$0")/../bundle/shell" && pwd)/profile-select.sh"
fails=0

run_case() { # $1=label  $2=expected  $3...=files to create
  label=$1; expected=$2; shift 2
  H=$(mktemp -d)
  for f in "$@"; do printf 'marker\n' > "$H/$f"; done
  got=$( HOME="$H" _DFR_SKIP_ETC=1 sh -c '. "$0"; _dfr_source_first_profile >/dev/null 2>&1; printf "%s" "$_DFR_SOURCED"' "$SELECT" )
  rm -rf "$H"
  if [ "$got" = "$expected" ]; then
    printf 'PASS %s (got %s)\n' "$label" "${got:-<none>}"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$label" "$expected" "${got:-<none>}"; fails=$((fails+1))
  fi
}

run_case "bash_profile wins over bashrc" .bash_profile .bash_profile .bashrc
run_case "bash_login when no bash_profile" .bash_login .bash_login .profile .bashrc
run_case "profile when no bash_*"          .profile   .profile .bashrc
run_case "bashrc only as last resort"      .bashrc    .bashrc

[ "$fails" -eq 0 ] || { printf '%d failures\n' "$fails"; exit 1; }
printf 'all profile-select tests passed\n'
```

- [ ] **Step 2: Run it (fails — helper missing)**

Run: `sh ssh-remote/tests/test-profile-select.sh`
Expected: FAIL (cannot source profile-select.sh / `_dfr_source_first_profile` not found).

- [ ] **Step 3: Write the helper**

Create `ssh-remote/bundle/shell/profile-select.sh`:

```sh
# POSIX login-profile selection, shared by the bash trampoline and the tests.
# Matches real login-bash: /etc/profile first, then the FIRST existing of
# bash_profile/bash_login/profile (which conventionally sources ~/.bashrc), and
# only ~/.bashrc if no profile exists. Records the chosen user file in
# $_DFR_SOURCED (for tests). Set $_DFR_SKIP_ETC=1 to skip /etc/profile (tests).
_dfr_source_first_profile() {
  _DFR_SOURCED=""
  if [ -z "${_DFR_SKIP_ETC:-}" ] && [ -r /etc/profile ]; then . /etc/profile; fi
  if   [ -r "$HOME/.bash_profile" ]; then _DFR_SOURCED=.bash_profile; . "$HOME/.bash_profile"
  elif [ -r "$HOME/.bash_login"   ]; then _DFR_SOURCED=.bash_login;   . "$HOME/.bash_login"
  elif [ -r "$HOME/.profile"      ]; then _DFR_SOURCED=.profile;      . "$HOME/.profile"
  elif [ -r "$HOME/.bashrc"       ]; then _DFR_SOURCED=.bashrc;       . "$HOME/.bashrc"
  fi
}
```

- [ ] **Step 4: Run it (passes)**

Run: `sh ssh-remote/tests/test-profile-select.sh`
Expected: `all profile-select tests passed`, exit 0.

- [ ] **Step 5: shellcheck**

Run: `shellcheck ssh-remote/bundle/shell/profile-select.sh ssh-remote/tests/test-profile-select.sh`
Expected: no errors (warnings about `.` sourcing dynamic paths may be info-level; resolve or `# shellcheck disable=SC1090`).

- [ ] **Step 6: Commit**

```bash
git add ssh-remote/bundle/shell/profile-select.sh ssh-remote/tests/test-profile-select.sh
git commit -m "feat(ssh-remote): deterministic login-profile selection + test"
```

---

## Task 4: Remote prompt snippets

**Files:**
- Create: `ssh-remote/bundle/shell/prompt.zsh`, `ssh-remote/bundle/shell/prompt.sh`

- [ ] **Step 1: Write the zsh prompt**

Create `ssh-remote/bundle/shell/prompt.zsh`:

```zsh
# Remote prompt (zsh): bright red "remote" segment + short host + cwd.
# Sourced by the zsh trampoline after the user's real ~/.zshrc.
setopt prompt_subst
#  = nerd-font server glyph; renders via the LOCAL terminal font.
PROMPT='%K{red}%F{white} '$''' %m %f%k %F{cyan}%~%f %# '
```

- [ ] **Step 2: Write the bash/POSIX prompt**

Create `ssh-remote/bundle/shell/prompt.sh`:

```sh
# Remote prompt (bash/sh): bright red "remote" segment + host + cwd.
# Sourced by the bash trampoline after the user's profile.
# Glyph needs bash >= 4.2 ($'\uXXXX'); fall back to an ASCII marker otherwise.
_dfr_glyph='[ssh]'
if [ -n "${BASH_VERSINFO:-}" ] && { [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ]; }; }; then
  _dfr_glyph=$''
fi
PS1="\[\e[41;97m\] ${_dfr_glyph} \h \[\e[0m\] \[\e[36m\]\w\[\e[0m\] \$ "
unset _dfr_glyph
```

- [ ] **Step 3: Verify the zsh prompt loads and sets PROMPT**

Run:
```bash
zsh -fc 'source ssh-remote/bundle/shell/prompt.zsh; [[ "$PROMPT" == *"%m"* ]] && echo prompt-ok'
```
Expected: `prompt-ok`.

- [ ] **Step 4: shellcheck the POSIX prompt**

Run: `shellcheck -s bash ssh-remote/bundle/shell/prompt.sh`
Expected: no errors. (`prompt.zsh` is zsh-only; shellcheck has no zsh mode — skip it there.)

- [ ] **Step 5: Commit**

```bash
git add ssh-remote/bundle/shell/prompt.zsh ssh-remote/bundle/shell/prompt.sh
git commit -m "feat(ssh-remote): remote prompt indicators (zsh + bash)"
```

---

## Task 5: Shell trampolines (zsh + bash)

**Files:**
- Create: `ssh-remote/bundle/zdotdir/.zshenv` `.zprofile` `.zshrc` `.zlogin`, `ssh-remote/bundle/bashrc`

Each trampoline sources the user's REAL counterpart first (preserving server env), then applies our overrides exactly once via a **shell-local** (never exported) guard so child interactive shells re-apply the prompt.

- [ ] **Step 1: Write `.zshenv`**

Create `ssh-remote/bundle/zdotdir/.zshenv`:
```zsh
# zsh trampoline: ZDOTDIR redirects per-user files here, so we load the real ones.
[[ -r "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
```

- [ ] **Step 2: Write `.zprofile`**

Create `ssh-remote/bundle/zdotdir/.zprofile`:
```zsh
[[ -r "$HOME/.zprofile" ]] && source "$HOME/.zprofile"
```

- [ ] **Step 3: Write `.zlogin`**

Create `ssh-remote/bundle/zdotdir/.zlogin`:
```zsh
# zsh -l reads .zlogin after .zshrc; preserve the user's.
[[ -r "$HOME/.zlogin" ]] && source "$HOME/.zlogin"
```

- [ ] **Step 4: Write `.zshrc`**

Create `ssh-remote/bundle/zdotdir/.zshrc`:
```zsh
# Load the user's real interactive config first…
[[ -r "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

# …then our overrides, once per shell (guard is shell-local, NOT exported, so a
# child interactive shell re-applies the remote prompt/aliases).
if [[ -z "$_DFR_ZSHRC_DONE" ]]; then
  typeset -g _DFR_ZSHRC_DONE=1
  [[ -r "$DOTFILES_REMOTE/shell/prompt.zsh" ]] && source "$DOTFILES_REMOTE/shell/prompt.zsh"
  alias v="$DFR_NVIM" vim="$DFR_NVIM" vi="$DFR_NVIM"
  export EDITOR="$DFR_NVIM"
fi
```

- [ ] **Step 5: Write `bashrc`**

Create `ssh-remote/bundle/bashrc`:
```sh
# bash trampoline (--init-file). Deterministic login-ish startup, then overrides.
# shellcheck source=/dev/null
[ -r "$DOTFILES_REMOTE/shell/profile-select.sh" ] && . "$DOTFILES_REMOTE/shell/profile-select.sh"

if [ -z "${_DFR_BASHRC_DONE:-}" ]; then
  _DFR_BASHRC_DONE=1   # shell-local (no export) — child shells re-apply
  command -v _dfr_source_first_profile >/dev/null 2>&1 && _dfr_source_first_profile
  # shellcheck source=/dev/null
  [ -r "$DOTFILES_REMOTE/shell/prompt.sh" ] && . "$DOTFILES_REMOTE/shell/prompt.sh"
  alias v="$DFR_NVIM"; alias vim="$DFR_NVIM"; alias vi="$DFR_NVIM"
  export EDITOR="$DFR_NVIM"
fi
```

- [ ] **Step 6: Syntax-check the trampolines**

Run:
```bash
for f in ssh-remote/bundle/zdotdir/.zshenv ssh-remote/bundle/zdotdir/.zprofile ssh-remote/bundle/zdotdir/.zshrc ssh-remote/bundle/zdotdir/.zlogin; do zsh -n "$f" && echo "ok $f"; done
bash -n ssh-remote/bundle/bashrc && echo "ok bashrc"
shellcheck -s bash ssh-remote/bundle/bashrc
```
Expected: `ok` for each; shellcheck clean (SC1090/SC1091 suppressed via the `source=` directives).

- [ ] **Step 7: Commit**

```bash
git add ssh-remote/bundle/zdotdir ssh-remote/bundle/bashrc
git commit -m "feat(ssh-remote): zsh + bash trampolines preserving server env"
```

---

## Task 6: Remote entrypoint `bootstrap.sh`

**Files:**
- Create: `ssh-remote/bundle/bootstrap.sh`

- [ ] **Step 1: Write `bootstrap.sh`**

Create `ssh-remote/bundle/bootstrap.sh`:
```sh
#!/bin/sh
# Remote entrypoint (run as: sh ~/.dotfiles-remote/bundle/bootstrap.sh).
# Sets isolated XDG for nvim, picks nvim/vim/vi, exports DFR_NVIM + DOTFILES_REMOTE,
# then execs the user's interactive shell wired to our trampolines. Falls back to a
# plain shell on any problem so the user is never locked out.

DFR="$HOME/.dotfiles-remote"
export DOTFILES_REMOTE="$DFR/bundle"
export DOTFILES_REMOTE_BOOTSTRAPPED=1   # session marker only (NOT an override gate)

# Isolated XDG: config from the synced bundle; writable state in $DFR/state so
# `rsync --delete` on bundle/ can never wipe it.
_cfg="$DOTFILES_REMOTE/xdg/config"
_st="$DFR/state"
mkdir -p "$_st/data" "$_st/state" "$_st/cache" 2>/dev/null

if command -v nvim >/dev/null 2>&1; then
  DFR_NVIM="env XDG_CONFIG_HOME=$_cfg XDG_DATA_HOME=$_st/data XDG_STATE_HOME=$_st/state XDG_CACHE_HOME=$_st/cache nvim"
elif command -v vim >/dev/null 2>&1; then
  DFR_NVIM="vim"; printf 'ssh-remote: nvim not found, using vim\n' >&2
else
  DFR_NVIM="vi";  printf 'ssh-remote: nvim/vim not found, using vi\n' >&2
fi
export DFR_NVIM

_sh="${SHELL:-/bin/sh}"
case "${_sh##*/}" in
  zsh)  exec env ZDOTDIR="$DOTFILES_REMOTE/zdotdir" "$_sh" -l -i ;;
  bash) exec "$_sh" --init-file "$DOTFILES_REMOTE/bashrc" -i ;;
  *)    exec "$_sh" -i ;;
esac

# Only reached if exec failed.
exec "${SHELL:-/bin/sh}" -i
```

- [ ] **Step 2: Make it executable and check syntax**

Run:
```bash
chmod +x ssh-remote/bundle/bootstrap.sh
sh -n ssh-remote/bundle/bootstrap.sh && echo "syntax ok"
shellcheck ssh-remote/bundle/bootstrap.sh
```
Expected: `syntax ok`; shellcheck clean.

- [ ] **Step 3: Smoke-test the env/shell-selection locally (no ssh)**

Run (simulate the remote side with this repo's bundle as `$DOTFILES_REMOTE`, forcing a quick exit):
```bash
HOME=$(mktemp -d) DFR_HOME_BUNDLE="$PWD/ssh-remote/bundle" \
sh -c 'mkdir -p "$HOME/.dotfiles-remote"; ln -s "$DFR_HOME_BUNDLE" "$HOME/.dotfiles-remote/bundle"; SHELL=/bin/sh sh "$HOME/.dotfiles-remote/bundle/bootstrap.sh" </dev/null' \
  <<<'echo "DFR_NVIM=[$DFR_NVIM]"; exit'
```
Expected: prints a line containing `DFR_NVIM=[env XDG_CONFIG_HOME=...nvim]` (or `[vim]`/`[vi]` if nvim absent), then exits. Confirms env wiring without needing a server.

- [ ] **Step 4: Commit (preserve the executable bit)**

```bash
git add ssh-remote/bundle/bootstrap.sh
git update-index --chmod=+x ssh-remote/bundle/bootstrap.sh
git commit -m "feat(ssh-remote): remote bootstrap entrypoint with XDG isolation + safe fallback"
```

---

## Task 7: The `ssh()` wrapper + guard/probe unit tests (TDD)

**Files:**
- Create: `zsh/ssh-remote.zsh`, `ssh-remote/tests/test-guard.zsh`, `ssh-remote/tests/fixtures/{plain,remotecommand,localforward,sessiontype-none,proxyjump,localcommand}.txt`

- [ ] **Step 1: Create `ssh -G` fixtures**

Create these files (trimmed `ssh -G` outputs — only keys the probe inspects):

`ssh-remote/tests/fixtures/plain.txt`:
```
user root
hostname 203.0.113.10
port 22
sessiontype default
requesttty auto
forkafterauthentication no
permitlocalcommand no
remotecommand none
```
`ssh-remote/tests/fixtures/remotecommand.txt`:
```
user root
sessiontype default
requesttty auto
remotecommand tmux attach
permitlocalcommand no
```
`ssh-remote/tests/fixtures/localforward.txt`:
```
user root
sessiontype default
requesttty auto
localforward 8080 127.0.0.1:80
remotecommand none
permitlocalcommand no
```
`ssh-remote/tests/fixtures/sessiontype-none.txt`:
```
user root
sessiontype none
requesttty no
remotecommand none
permitlocalcommand no
```
`ssh-remote/tests/fixtures/proxyjump.txt`:
```
user root
sessiontype default
requesttty auto
proxyjump jump-host
remotecommand none
permitlocalcommand no
```
`ssh-remote/tests/fixtures/localcommand.txt`:
```
user root
sessiontype default
requesttty auto
remotecommand none
permitlocalcommand yes
localcommand printf hi
```

- [ ] **Step 2: Write the failing test**

Create `ssh-remote/tests/test-guard.zsh`:
```zsh
#!/usr/bin/env zsh
# Unit tests for the bare-form parser and the ssh -G config probe.
emulate -L zsh
here="${0:A:h}"
source "$here/../../zsh/ssh-remote.zsh"   # defines _dfr_* helpers (and ssh(), unused here)

fails=0
check() { # $1=label $2=expected(0/1) $3=actual_rc
  if [[ "$2" == "$3" ]]; then print "PASS $1"; else print "FAIL $1 (want $2 got $3)"; ((fails++)); fi
}

# --- bare-host parser: returns 0 + echoes host only for the bare form ---
host=$(_dfr_bare_host myhost);            check "bare host"            0 $?
[[ "$host" == myhost ]] || { print "FAIL bare host value ($host)"; ((fails++)); }
_dfr_bare_host user@myhost >/dev/null;    check "user@host"            0 $?
_dfr_bare_host -p 2222 myhost >/dev/null; check "option => passthrough" 1 $?
_dfr_bare_host myhost uptime >/dev/null;  check "remote cmd => pass"    1 $?
_dfr_bare_host -N myhost >/dev/null;      check "-N => passthrough"     1 $?
_dfr_bare_host >/dev/null;                check "no operand => pass"    1 $?

# --- config probe: stub _dfr_ssh_config to read a fixture (zsh dynamic scope
# makes `fx` and `here` visible inside the redefined function at call time) ---
probe() { local fx="$1"; _dfr_ssh_config() { cat "$here/fixtures/$fx.txt" }; _dfr_should_passthrough_cfg x; print $? }
check "plain => intercept"          1 "$(probe plain)"
check "remotecommand => passthrough" 0 "$(probe remotecommand)"
check "localforward => passthrough"  0 "$(probe localforward)"
check "sessiontype none => pass"     0 "$(probe sessiontype-none)"
check "proxyjump => intercept"       1 "$(probe proxyjump)"
check "localcommand => passthrough"  0 "$(probe localcommand)"

(( fails == 0 )) || { print "$fails failures"; exit 1 }
print "all guard tests passed"
```

- [ ] **Step 3: Run it (fails — wrapper missing)**

Run: `zsh ssh-remote/tests/test-guard.zsh`
Expected: FAIL — cannot source `zsh/ssh-remote.zsh` (does not exist yet).

- [ ] **Step 4: Write the wrapper**

Create `zsh/ssh-remote.zsh`:
```zsh
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
      requesttty) [[ "$val" == no ]] && return 0 ;;
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
  setopt local_options

  # Fast passthroughs.
  [[ -n "$SSH_NO_BUNDLE" ]] && { command ssh "$@"; return }
  [[ -t 0 && -t 1 ]]       || { command ssh "$@"; return }

  local host
  host="$(_dfr_bare_host "$@")"        || { command ssh "$@"; return }
  _dfr_should_passthrough_cfg "$host"  && { command ssh "$@"; return }

  # Intercept: one shared ControlMaster for mkdir + rsync + final connect.
  local remote='~/.dotfiles-remote/bundle'
  local -a cm=(-o ControlMaster=auto -o ControlPersist=30 \
               -o "ControlPath=$HOME/.ssh/cm-dotfiles-%r@%h-%p")

  if ! command ssh -T "${cm[@]}" "$host" "mkdir -p $remote" 2>/dev/null; then
    print -u2 "ssh-remote: cannot prepare $host; using plain ssh."
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

  _dfr_set_title "$host"
  command ssh -t "${cm[@]}" "$host" "exec sh $remote/bootstrap.sh"
  local rc=$?
  _dfr_clear_title
  command ssh "${cm[@]}" -O exit "$host" 2>/dev/null
  return $rc
}
```

- [ ] **Step 5: Run the guard tests (pass)**

Run: `zsh ssh-remote/tests/test-guard.zsh`
Expected: all `PASS` lines, then `all guard tests passed`, exit 0.

- [ ] **Step 6: Verify passthrough doesn't break normal ssh in an interactive shell**

Run:
```bash
zsh -ic 'source zsh/ssh-remote.zsh; SSH_NO_BUNDLE=1 ssh -V'
```
Expected: prints the OpenSSH version (passthrough path runs `command ssh -V`), exit 0.

- [ ] **Step 7: Commit**

```bash
git add zsh/ssh-remote.zsh ssh-remote/tests/test-guard.zsh ssh-remote/tests/fixtures
git commit -m "feat(ssh-remote): ssh() wrapper with bare-form guard, config probe, ControlMaster"
```

---

## Task 8: wezterm tab title from `ssh_host` user-var

**Files:**
- Modify: `wezterm.lua:136-144` (the `format-tab-title` handler)

- [ ] **Step 1: Replace the handler**

In `wezterm.lua`, replace the existing `format-tab-title` block:
```lua
-- Tab title: always show current directory name
wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local cwd = pane.current_working_dir
  if cwd then
    local path = cwd.file_path or tostring(cwd)
    local dir = path:match('([^/]+)/?$') or path
    return ' ' .. dir .. ' '
  end
end)
```
with:
```lua
-- Tab title: SSH host (set by the ssh() wrapper's user-var) when present,
-- otherwise the current directory name.
wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local ssh_host = pane.user_vars and pane.user_vars.ssh_host
  if ssh_host and #ssh_host > 0 then
    return '  ' .. ssh_host .. ' ' -- nerd-font server glyph + host
  end
  local cwd = pane.current_working_dir
  if cwd then
    local path = cwd.file_path or tostring(cwd)
    local dir = path:match('([^/]+)/?$') or path
    return ' ' .. dir .. ' '
  end
end)
```

- [ ] **Step 2: Lua-syntax sanity check**

Run: `luajit -bl wezterm.lua >/dev/null 2>&1 && echo "lua ok" || lua -e 'assert(loadfile("wezterm.lua"))' && echo "lua ok"`
Expected: `lua ok` (parse-only; `wezterm`/`require` aren't resolved here — that's fine, we only check syntax). If neither `luajit` nor `lua` is installed, skip and rely on Step 3.

- [ ] **Step 3: Manual verification (own message in subagent flow)**

1. Reload wezterm config (Cmd+Shift+R) or restart it.
2. In a wezterm tab, run `printf '\e]1337;SetUserVar=ssh_host=%s\a' "$(printf example-host | base64)"`.
   Expected: the tab title becomes `  example-host`.
3. Run `printf '\e]1337;SetUserVar=ssh_host=\a'`.
   Expected: the tab title reverts to the cwd directory name.

- [ ] **Step 4: Commit**

```bash
git add wezterm.lua
git commit -m "feat(ssh-remote): wezterm tab title shows ssh host via user-var"
```

---

## Task 9: Documentation

**Files:**
- Modify: `CLAUDE.md`, `README.md`

- [ ] **Step 1: Add a CLAUDE.md section**

Add a `### SSH Remote (ssh-remote/)` subsection under "Architecture & Key Patterns" summarizing: the `ssh()` wrapper intercepts only the bare form (TTY + zero options + `ssh -G` plain-login probe); bundle rsynced to `~/.dotfiles-remote/bundle/` over a shared ControlMaster; remote shell via trampolines preserving server env; nvim XDG-isolated under `~/.dotfiles-remote/state/`; `SSH_NO_BUNDLE=1` escape hatch; `make ssh-remote-vendor/install/test/clean-host`. Note the public-repo rule: **no host names in tracked files** (per-host tweaks go in gitignored `zsh/local.zsh`).

- [ ] **Step 2: Add a README section**

Document install (`make ssh-remote-install`), usage (`ssh <host>` just works; `SSH_NO_BUNDLE=1 ssh <host>` to bypass), the `v`/`vim` remote alias, and the `make ssh-remote-clean-host HOST=…` cleanup.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs(ssh-remote): document wrapper, bundle, and make targets"
```

---

## Task 10: End-to-end verification against a real host (manual)

Not a commit — a verification gate. Pick a disposable/own host (e.g. your personal box), not prod.

- [ ] **Step 1: Install and run the test suite**

Run: `make ssh-remote-install && make ssh-remote-test`
Expected: install succeeds; all tests pass (`nvim-ok`, guard + profile-select pass).

- [ ] **Step 2: Connect and observe**

Run: `ssh <your-own-host>`
Expected, in order:
- single auth prompt (or none with agent auth) — not 2–3;
- wezterm tab title shows `  <host>`;
- remote prompt shows the bright red host segment;
- `v somefile` opens nvim with your keymaps + colorscheme (or vim/vi fallback if nvim absent).

- [ ] **Step 3: Confirm isolation & exit behavior**

On the remote: `ls ~/.dotfiles-remote` → shows `bundle/` and `state/`; `ls ~/.local/state/nvim 2>/dev/null` → absent/unchanged. Then `exit`.
Expected on return to local: tab title reverts to cwd; local shell/tab still alive.

- [ ] **Step 4: Confirm passthrough is intact**

Run: `scp --help >/dev/null && git ls-remote <a-git-ssh-remote> >/dev/null && echo passthrough-ok`; also `SSH_NO_BUNDLE=1 ssh <host>` (plain login, no bundle).
Expected: `passthrough-ok`; the `SSH_NO_BUNDLE` session shows the server's normal prompt.

- [ ] **Step 5: Cleanup test**

Run: `make ssh-remote-clean-host HOST=<your-own-host>` then reconnect once.
Expected: clean removal, and the next connect re-syncs the full bundle (slower once), then fast diffs.

---

## Self-Review notes (author)

- **Spec coverage:** guard (T7), config probe (T7), ControlMaster single-auth (T7), `-T` internal / `-t` final (T7), sync + tar fallback + degrade (T7), bundle/state split & XDG isolation (T2/T6), trampolines incl. `.zlogin` + `/etc/profile` bash policy (T3/T5), two-guard model (T5/T6), prompt (T4), nvim incl. grep_live guard (T2), wezterm title (T8), vendoring manifest + `.git` strip + gitignore (T1), `sh bootstrap.sh` + tracked +x (T6/T1), public-repo safety (T9 + no host names anywhere in this plan). All mapped.
- **Placeholders:** only `PLACEHOLDER_SHA`, intentionally resolved in T1S4.
- **Type/name consistency:** `_dfr_bare_host`, `_dfr_ssh_config`, `_dfr_should_passthrough_cfg`, `_dfr_set_title`, `_dfr_clear_title`, `_DFR_REPO`, `_DFR_BUNDLE`, `DOTFILES_REMOTE`, `DFR_NVIM`, `_DFR_ZSHRC_DONE`, `_DFR_BASHRC_DONE`, `_dfr_source_first_profile`/`_DFR_SOURCED` used identically across tasks.
