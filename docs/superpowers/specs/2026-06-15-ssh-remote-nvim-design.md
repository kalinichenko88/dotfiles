# SSH Remote nvim + prompt + wezterm title — Design

**Date:** 2026-06-15
**Status:** Approved (design); pending implementation plan
**Repo:** PUBLIC — no host-specific data, secrets, or real hostnames may appear in tracked files.

## Goal

When connecting to a server via the bare form `ssh [user@]<host>` (hosts defined in `~/.ssh/config`), automatically:

1. Bring along a **portable nvim config** so the server has a usable editor matching local muscle memory — without permanently installing or polluting the server.
2. Make the **remote shell prompt** visually obvious that the session is remote (bright "warning" indicator + host name).
3. Set the **wezterm tab title** to the host for the duration of the SSH session, restoring it on exit.

User requirement: typing `ssh <host>` "just works" with no extra steps; adding a new host to `~/.ssh/config` requires no changes here.

## Approved decisions (from brainstorming)

- **nvim delivery:** lightweight portable config carried to the server on connect (rsync), nvim runs *on* the server. Full local config stays local; prod boxes not polluted.
- **Config richness:** zero-dependency + **vendored** plugins via nvim's native `pack/` mechanism (no plugin manager, no network, no compiler on the server).
- **Remote prompt:** zero-dependency shell snippet injected into the remote interactive shell via `ZDOTDIR`/`--init-file`; bright remote indicator + host name. No binaries shipped.
- **Title:** wezterm only, via wezterm user-var (`OSC 1337 SetUserVar=ssh_host`) read by the `format-tab-title` handler.
- **`ssh` override** that intercepts **only the bare form** (no CLI options at all); everything else passes through untouched.
- **Stable cache dir `~/.dotfiles-remote/`** on the server (rsync sends only diffs).

## State model (precise — supersedes any looser wording)

- We **never modify** the server's shell rc files, profile files, or system paths.
- The **only** persistent artifact on the server is the self-contained directory `~/.dotfiles-remote/`, removable at any time with `rm -rf ~/.dotfiles-remote`.
- **Remote layout splits immutable from mutable:**
  - `~/.dotfiles-remote/bundle/` — the rsync target (`--delete` safe; contains only files we ship: `bootstrap.sh`, `zdotdir/`, `bashrc`, `shell/`, `xdg/config/nvim/`).
  - `~/.dotfiles-remote/state/{data,state,cache}` — nvim runtime (XDG data/state/cache). Created at runtime, **never** an rsync target, so `--delete` cannot wipe it.
- All nvim runtime state (shada, undo, cache, data) is redirected **inside** `~/.dotfiles-remote/state/`; only `XDG_CONFIG_HOME` points into the synced `bundle/`. nvim does **not** write to the standard XDG locations.
- Our prompt and aliases are injected **only for the session's lifetime** via `ZDOTDIR`/`--init-file`, never persisted into the server's own rc files.

## Architecture

A single zsh wrapper over `ssh` orchestrates everything per connect:

0. **Shared connection** — a transient ControlMaster so all wrapper ssh/rsync calls reuse one auth.
1. **Guard** — intercept only the bare form; otherwise passthrough.
2. **Sync** — `rsync` the bundle to `~/.dotfiles-remote/bundle/` on the server (with fallbacks and a no-bundle degrade path).
3. **Title** — emit wezterm `SetUserVar=ssh_host=<base64 host>`.
4. **Launch** — `ssh -t <host> 'exec sh ~/.dotfiles-remote/bundle/bootstrap.sh'`.
5. **Restore** — on exit, clear the user-var (tab title reverts to cwd) and close the master.

### Repo layout

```
zsh/ssh-remote.zsh                  # auto-sourced (zshrc loops over *.zsh); ssh() wrapper + guard
ssh-remote/
  plugins.txt                       # TRACKED manifest: <name> <git-url> <commit-sha> per line
  bundle/                           # rsynced to ~/.dotfiles-remote/bundle/ on the server (minus .git)
    bootstrap.sh                    # POSIX sh: detect $SHELL, exec right shell with our rc, safe fallback
    zdotdir/.zshenv .zprofile .zshrc .zlogin  # zsh trampolines (DOTTED; ZDOTDIR=~/.dotfiles-remote/bundle/zdotdir)
    bashrc                          # bash trampoline (--init-file target)
    shell/prompt.zsh                # remote PROMPT indicator (zsh)
    shell/prompt.sh                 # remote PS1 indicator (bash/sh)
    xdg/config/nvim/
      init.lua                      # zero-dep config; prepends packpath to ./pack
      pack/plugins/start/           # vendored plugins (gitignored, populated by make target, .git stripped)
wezterm.lua                         # format-tab-title: prefer user-var ssh_host over cwd
Makefile                            # ssh-remote-vendor, ssh-remote-install targets
.gitignore                          # += ssh-remote/bundle/xdg/config/nvim/pack/
```

## Components

### 1. `ssh()` wrapper (`zsh/ssh-remote.zsh`)

**Repo root** is derived from the script's own path, independent of env:
`local repo="${${(%):-%x}:A:h:h}"` (resolves `…/zsh/ssh-remote.zsh` → repo root). `$DOTFILES` is **not** assumed (only `DOTFILES_ZSH` exists in `zsh/zshrc:3`).

**Guard contract — intercept ONLY the bare form:**

Intercept (i.e. do the bundle dance) **iff ALL** of these hold:
- `$SSH_NO_BUNDLE` is unset, and
- **both** stdin and stdout are TTYs (`[[ -t 0 && -t 1 ]]`) — guards against `ssh <host> < file` and other scripted single-operand usage, and
- the CLI argument list contains **zero option flags** (nothing starting with `-`), and
- there is **exactly one** operand, the `[user@]host` token, and
- a **config probe** of that host shows a plain interactive login (see below).

Otherwise → `command ssh "$@"` verbatim, no bundle, no `-t`, no semantic change.

**Config probe (`ssh -G <host>`):** CLI flags alone don't capture session semantics — `~/.ssh/config` can set them per host. `ssh -G <host>` resolves the effective config **locally, without connecting** (cheap), and we passthrough if any of these appear:
- `remotecommand` set (non-empty / not `none`)
- `localforward` / `remoteforward` / `dynamicforward` present
- `sessiontype none`
- `requesttty no`
- `forkafterauthentication yes`
- `localcommand` set **and** `permitlocalcommand yes` — bare `ssh <host>` would run it once; our multiple ssh/rsync invocations could run it several times, so passthrough to preserve once-only semantics

`proxyjump` / `proxycommand` / `controlmaster` are **not** passthrough triggers — they are valid interactive logins (e.g. a DB host reached via a jump must still be intercepted).

Rationale: any CLI option (`-N -f -T -W -M -O -L -R -D`, `-p -i -F -J -l -o …`) signals a non-interactive, forwarding, control-master, or otherwise special session, **or** carries connection parameters we would otherwise have to thread into both `ssh` and `rsync -e`. Refusing to intercept those, plus the config probe, is simpler and strictly safer ("when in doubt, passthrough"). All ordinary login hosts in `~/.ssh/config` are reachable via the bare form (Port/User/IdentityFile/ProxyJump live in the config), so `ssh <host>` still "just works"; `scp`/`sftp`/`git`/standalone `rsync` are unaffected (they call the `ssh` binary, not this function).

**On intercept** — all wrapper ssh/rsync calls share **one authenticated connection** via a transient ControlMaster, so a password/MFA host prompts **once**, not per call (otherwise mkdir + rsync + final = 2–3 prompts, breaking "just works"):

0. **Shared connection.** Build a per-invocation control-socket option set:
   `cm=(-o ControlMaster=auto -o ControlPersist=30 -o ControlPath="$HOME/.ssh/cm-dotfiles-%r@%h-%p")`.
   The first ssh below opens the master; mkdir/rsync/final all attach to it → single auth. The dedicated `cm-dotfiles-*` path never collides with the user's own `ControlPath` in `~/.ssh/config`. **Assumption:** on a host with neither agent/key auth nor multiplexing, behavior degrades to standard per-call prompting — still correct, just not single-auth.

1. **Sync** (target hardcoded, never derived from input; `bundle/` only — `state/` never touched). Internal commands force **no TTY** (`-T`) so a host with `RequestTTY force` can't corrupt the rsync/tar byte stream (PTY is per-session, so the master being `-T` doesn't stop the final `-t` slave from getting its PTY):
   - `command ssh -T "${cm[@]}" "$host" 'mkdir -p ~/.dotfiles-remote/bundle'` — opens the master & ensures the target exists. **Do not** use `rsync --mkpath`: local macOS rsync is `openrsync` ("2.6.9 compatible"); `--mkpath` needs rsync ≥ 3.2.3 → would fail locally and force tar, losing diff-sync.
   - Preferred: `command rsync -az --delete --exclude='.git/' -e "ssh -T ${cm[*]}" "$repo/ssh-remote/bundle/" "<host>:~/.dotfiles-remote/bundle/"` (plain rsync, openrsync-compatible; diffs only on later connects).
   - Fallback if remote lacks `rsync`: `tar` pipe over `ssh -T "${cm[@]}"` — `… 'mkdir -p …/bundle' && tar -C "$repo/ssh-remote/bundle" --exclude='.git' -cf - . | ssh -T "${cm[@]}" "$host" 'tar -C ~/.dotfiles-remote/bundle -xf -'`. tar does **not** prune removed files (documented; `make ssh-remote-clean-host HOST=…` does a clean re-sync).
   - **Sync failure → degrade, don't block:** warn and `command ssh -t "$host"; return $?` (plain login, no bundle). **Never `exec`** inside `ssh()` — it would replace the local interactive shell, losing the shell/tab on disconnect.

2. **Title on:** emit `OSC 1337 ; SetUserVar=ssh_host=<base64(host)>` to the local terminal.

3. **Connect (interactive, `-t`):** `command ssh -t "${cm[@]}" "$host" 'exec sh ~/.dotfiles-remote/bundle/bootstrap.sh'`. Launched via `sh <path>` (not a bare path) so it does **not** depend on the executable bit or an `exec`-mounted home; the file is also tracked +x as belt-and-suspenders.

4. **Title off + teardown (always, after ssh returns):** emit `SetUserVar=ssh_host=` (empty) so the tab reverts to cwd, then close the master: `command ssh "${cm[@]}" -O exit "$host" 2>/dev/null`.

### 2. Remote shell startup model (precise)

`bootstrap.sh` (POSIX sh) is the remote login command. It reads `$SHELL`, then `exec`s the matching interactive shell wired to our trampolines.

**Two distinct guards (do not conflate):**
- `DOTFILES_REMOTE_BOOTSTRAPPED=1` — exported by `bootstrap.sh` as a *session marker only*. It is **never** used to gate whether trampolines apply their overrides (doing so would suppress prompt/aliases on the very first launch, since the marker is already set by the time the trampolines run). Its only job: if `bootstrap.sh` itself is somehow re-invoked within the session, it can detect that and skip re-exec.
- **Per-file guards** — each trampoline checks-and-sets its **own** variable (`_DOTFILES_REMOTE_ZSHRC_DONE`, `_DOTFILES_REMOTE_BASHRC_DONE`, …) around applying *our* overrides, so re-sourcing the same rc within one shell doesn't double-apply. On first launch these are unset, so overrides **do** apply. These guards are **shell-local (never `export`ed)** — otherwise a child interactive shell would inherit `_DOTFILES_REMOTE_*_DONE` and skip its prompt/aliases. Keeping them local means each fresh interactive shell re-applies overrides while still preventing same-shell double-source.

Avoiding *double-sourcing of the same upstream rc* is handled per-shell by the startup policies below (zsh leaves system files to zsh; bash sources only the first existing profile), independent of both guards above.

- **zsh** → `exec env ZDOTDIR="$HOME/.dotfiles-remote/bundle/zdotdir" zsh -l -i`
  - System files (`/etc/zshenv`, `/etc/zprofile`, `/etc/zshrc`, `/etc/zlogin`) are loaded **by zsh itself** (not affected by `ZDOTDIR`) — we do **not** source them, avoiding double-source.
  - Per-user startup files are taken from `ZDOTDIR` (our `zdotdir/`). Our dotted `.zshenv`/`.zprofile`/`.zshrc`/`.zlogin` each source the **real** user counterpart (`$HOME/.zshenv`, `$HOME/.zlogin`, etc.) under the per-file guard, so the user's remote env — including `~/.zlogin` (which a real `zsh -l` reads after `.zshrc`) — is preserved. Overrides (prompt, aliases) are applied **only** in our `.zshrc`, after sourcing the real one.
- **bash** → `exec bash --init-file "$HOME/.dotfiles-remote/bundle/bashrc" -i`
  - Our `bashrc` follows a **deterministic** policy that matches real login-bash and avoids double-sourcing:
    1. source `/etc/profile` if it exists (a real login bash reads it first, for system-wide login env), then
    2. source the **first existing** of `~/.bash_profile` → `~/.bash_login` → `~/.profile` (which conventionally sources `~/.bashrc` itself, so we do **not** source `~/.bashrc` again); **only if none of those exist** do we source `~/.bashrc`, then
    3. apply our overrides last.
  - Marked **best-effort**: bash startup is distro-dependent; if a server lacks a profile that sources `.bashrc`, behavior matches a real login bash (which would also skip it).
- **other / any error** → `exec "$SHELL" -i` (or `exec "$SHELL" -l -i`): a plain shell, never locking the user out.

### 3. Portable nvim (`ssh-remote/bundle/xdg/config/nvim/`)

Invoked via the `v`/`vim` aliases (defined in the trampolines) with **fully isolated XDG state** — config from the synced `bundle/`, all writable state in the rsync-untouched `state/`:
```
env XDG_CONFIG_HOME=$HOME/.dotfiles-remote/bundle/xdg/config \
    XDG_DATA_HOME=$HOME/.dotfiles-remote/state/data \
    XDG_STATE_HOME=$HOME/.dotfiles-remote/state/state \
    XDG_CACHE_HOME=$HOME/.dotfiles-remote/state/cache \
    nvim
```
nvim reads `$XDG_CONFIG_HOME/nvim/init.lua` from the synced bundle and writes shada/undo/cache/data only under `~/.dotfiles-remote/state/`. Because `state/` is never an rsync target, `rsync --delete` on `bundle/` cannot wipe nvim's runtime state. Nothing touches the standard `~/.local/state/nvim` etc.

`init.lua` — **no plugin manager**, explicit content (not "a subset"):

- **Options (server-appropriate, enumerated):** `mapleader=' '`, `number`, `signcolumn=yes`, `termguicolors`, `cursorline`, `mouse=a`, `expandtab`/`shiftwidth=2`/`tabstop=2`/`softtabstop=2`, `smartindent`, `wrap=false`, `scrolloff=8`, `splitright`/`splitbelow`, `ignorecase`/`smartcase`, `hidden`, `swapfile=false`, `undofile=true` (writes inside isolated XDG state). **Clipboard (updated after live testing):** set `clipboard=unnamedplus` with the built-in **OSC 52** provider (`vim.ui.clipboard.osc52`, `pcall`-guarded for nvim <0.10) so `y` reaches the *local* clipboard over SSH via wezterm; paste reads the remote nvim's own register (no terminal round-trip, which OSC52 paste would otherwise stall on).
- **Keymaps (remapped to vendored plugins, no dangling commands):** `<Esc>`→clear highlight, `<leader>w`→save, `]b`/`[b`→buffers, `<A-j>`/`<A-k>`→move line (normal+visual). Explorer/finder maps point at **mini.nvim**, not Neotree/Telescope: `<leader>e`→`MiniFiles`, `<leader>ff`→`MiniPick files`, `<leader>fb`→`MiniPick buffers`.
- **CLI-tool-aware grep (per mini.pick docs):** `files()` falls back to `vim.fs.dir()` and `grep()` to a Lua matcher when no `rg`/`fd`/`git` is present, **but `grep_live()` throws an error** with no CLI tool. So `init.lua` checks `vim.fn.executable('rg')`/`'git'` at startup: if either is present → `<leader>fg`→`MiniPick grep_live`; otherwise → `<leader>fg`→`MiniPick grep` (the slower Lua-fallback variant) plus a one-line `:notify` that live-grep is unavailable. No map ever errors on a bare server.
- No LSP/diagnostic maps (no LSP on the bundle).
- `vim.opt.packpath:prepend(<this nvim dir>)` so `pack/plugins/start/*` auto-load natively.
- Vendored: **mini.nvim** (files / pick / statusline / surround / comment / pairs) + a single self-contained **colorscheme** (one fixed theme — no macOS dark/light auto-switch on the server). Configured inline.

If nvim is absent on the host, `bootstrap.sh` points `v`/`vim` at `vim`/`vi` and prints a one-line notice.

### 4. wezterm title (`wezterm.lua`)

Modify the existing `format-tab-title` handler: if `tab.active_pane.user_vars.ssh_host` is non-empty, render `  <host>`; otherwise fall back to the current cwd-dir logic. The wrapper sets/clears the user-var, so the title tracks SSH session state automatically.

## Vendoring & installation

- **Manifest (`ssh-remote/plugins.txt`, TRACKED):** one `<name> <git-url> <commit-sha>` per line. Pins exact versions → reproducible.
- `make ssh-remote-vendor` — for each manifest line: clone (or fetch) into `ssh-remote/bundle/xdg/config/nvim/pack/plugins/start/<name>`, `git checkout <sha>`, then **`rm -rf <name>/.git`** (no nested repo, nothing extra rsynced). `pack/` stays gitignored; the manifest is the source of truth. Idempotent.
- `make ssh-remote-install` — wrapper is auto-sourced (zshrc loops over `zsh/*.zsh`); this target verifies the bundle is vendored, ensures `bundle/bootstrap.sh` is tracked executable (`chmod +x` / `git update-index --chmod=+x`), and reminds the user to `reload`.

## Public-repo safety rules (HARD constraints)

The repo is PUBLIC. Non-negotiable:

1. **No host-specific data in tracked files** — no hostnames, IPs, roles, or per-host lists in `ssh-remote.zsh`, the bundle, manifests, **or this spec**. Use `<host>` / `example-host` in examples. Any opt-out list or per-host tweak lives in `zsh/local.zsh` (already gitignored). The host is read only at runtime from the user's typed command.
2. **`rsync --delete` / tar target only the hardcoded `~/.dotfiles-remote/bundle/`** — never `$HOME`, never `~/.dotfiles-remote/state/`, never a path derived from user input.
3. **`.gitignore` excludes the vendored `pack/`** so plugin clones never get committed; the tracked `plugins.txt` manifest pins versions instead.
4. Trampolines **read** the server's rc to preserve env, never write to it, never transmit anything off the server.
5. Awareness (not a repo leak): prompt and tab title display the host alias — visible during screen-share.

## Out of scope (YAGNI)

- No LSP / Mason / treesitter on servers.
- No starship binary shipped (zero-dep prompt instead).
- No kitty title integration (wezterm only, by decision).
- No permanent full-config install on any box.
- ~~No auto-install of nvim on servers~~ **(revised after live testing):** when a server has no nvim, a pinned, checksum-verified official build is downloaded once into `~/.dotfiles-remote/state/`; vim/vi remain the fallback if the download/verify/run fails.
- No interception of option-bearing `ssh` invocations — passthrough by design.

## Risks & mitigations

- **Broken bootstrap disrupts login** → falls back to plain `$SHELL -i`; `SSH_NO_BUNDLE=1 ssh …` and `command ssh …` always bypass.
- **Guard misfire** → only the strict bare form (no CLI options, stdin+stdout TTY, plain-login per `ssh -G` probe) is intercepted; forwarding/remote-command/no-tty hosts pass through; `SSH_NO_BUNDLE=1` escape hatch.
- **Sync fails** → degrade to plain `command ssh -t <host>` with a warning; connection never blocked.
- **Server without rsync** → tar fallback (no `--delete`; documented).
- **Server without nvim** → `v` falls back to `vim`/`vi` with a notice.
- **Double-sourcing / wrong startup** → precise per-shell startup policy (zsh: system files left to zsh, user files incl. `.zlogin` via ZDOTDIR; bash: `/etc/profile` then first-existing user profile). Session marker `DOTFILES_REMOTE_BOOTSTRAPPED` is loop-detection only; per-file guards (`_DOTFILES_REMOTE_*_DONE`) gate override re-application — never the first-run application.
- **rsync `--delete` wiping nvim state** → mitigated by the `bundle/` (synced) vs `state/` (runtime) split; `--delete` only ever runs against `bundle/`.
- **Local shell lost on disconnect** → the `ssh()` function never `exec`s; it calls `command ssh` and returns, so the local shell/tab survive (title-off runs after).
- **Non-reproducible plugins** → tracked `plugins.txt` with pinned SHAs; vendor strips `.git`.
- **Multiple auth prompts (password/MFA)** → all wrapper calls share one transient ControlMaster, so auth happens once; degrades to standard prompting only where multiplexing is unsupported.
- **`RequestTTY force` corrupting sync** → internal mkdir/rsync/tar use `ssh -T`; only the final interactive connect uses `-t`.
- **`bootstrap.sh` not executable / noexec home** → launched as `sh <path>`, independent of the +x bit and exec-mount; install also keeps it tracked +x.
- **`grep_live` errors with no `rg`/`git`** → startup detects the tool; `<leader>fg` maps to `grep_live` only when available, else to `grep` (Lua fallback) with a notice.
- **First-connect latency** → stable cache dir; subsequent connects send only rsync diffs.
