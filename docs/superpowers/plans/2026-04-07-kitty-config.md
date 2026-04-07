# Kitty Terminal Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a kitty terminal configuration to the dotfiles repo that mirrors the existing wezterm setup, with a `make kitty-config-install` target and automatic dark/light theme switching.

**Architecture:** A `kitty/` directory at the repo root containing `kitty.conf`, a `theme-sync.sh` shell script, and a `themes/` subdirectory with vendored dark/light theme files plus a `current-theme.conf` symlink. The Makefile symlinks the whole `kitty/` directory to `~/.config/kitty/`. A zshrc hook runs `theme-sync.sh` on each shell startup to swap the symlink based on macOS appearance and call `kitty @ load-config` for live reload.

**Tech Stack:** Kitty (config DSL), POSIX shell, GNU Make, zsh

**Spec:** [`docs/superpowers/specs/2026-04-07-kitty-config-design.md`](../specs/2026-04-07-kitty-config-design.md)

**Branch:** `feat/kitty-config` (already created)

---

## File Structure

**Files to create:**
- `kitty/kitty.conf` — main config (font, cursor, padding, scrollback, layouts, keybindings, theme include, remote control)
- `kitty/theme-sync.sh` — shell script that detects macOS appearance and swaps the theme symlink
- `kitty/themes/dark.conf` — vendored from upstream `kanagawabones.conf`
- `kitty/themes/light.conf` — vendored from upstream `AtomOneLight.conf`
- `kitty/themes/current-theme.conf` — symlink (committed pointing at `dark.conf` as default)

**Files to modify:**
- `Makefile` — add `KITTY_CONFIG_DIR` variable, `kitty-config-install` target, update `.PHONY`
- `zsh/zshrc` — add the theme-sync hook line at the bottom
- `Brewfile` — add `cask "kitty"` (alphabetical position, after `cask "ghostty"`)
- `CLAUDE.md` — add a "Kitty Configuration" section under "Architecture & Key Patterns"
- `README.md` — add `kitty/` to the Contents list and add a "Kitty" install section

**Why this decomposition:** Each file has one responsibility — `kitty.conf` for static settings/keybindings, `theme-sync.sh` for the runtime appearance check, `themes/*.conf` for color data, the Makefile target for installation. Files that change together (the kitty config bundle) live together in `kitty/`. Doc updates are batched at the end so we only touch CLAUDE.md/README.md once.

**Note on testing:** This is a dotfiles repo, not application code. There are no unit tests. "Tests" in this plan are **verification commands** — running `kitty --version`, checking symlink targets, parsing the config with `kitty +runpy`, etc. Each task ends with a verification step before commit.

**Note on commits:** Each task is one commit. The hook `check-docs-before-commit` will block the first commit attempt of each session and ask Claude to review docs — re-running the same `git commit` command will pass through (the flag is session-scoped). When a task adds nothing user-visible (e.g. internal script), the docs review is a no-op confirmation.

---

## Task 1: Vendor the dark theme file

**Files:**
- Create: `kitty/themes/dark.conf`

- [ ] **Step 1: Create the kitty/themes/ directory**

```bash
mkdir -p kitty/themes
```

- [ ] **Step 2: Download the upstream kanagawabones theme**

```bash
curl -fsSL https://raw.githubusercontent.com/kovidgoyal/kitty-themes/master/themes/kanagawabones.conf -o kitty/themes/dark.conf
```

Expected: file created, no error. Verify with `head -3 kitty/themes/dark.conf` — should show kitty config syntax (likely starts with a comment or `background` line).

- [ ] **Step 3: Add a header comment recording the source**

Edit `kitty/themes/dark.conf` and prepend these three lines at the very top:

```
# Vendored from https://github.com/kovidgoyal/kitty-themes/blob/master/themes/kanagawabones.conf
# Matches wezterm.lua scheme_for_appearance('Dark') = 'kanagawabones'
# Do not edit — re-download from upstream to update
```

- [ ] **Step 4: Verify the file is non-empty and parseable as kitty config**

```bash
test -s kitty/themes/dark.conf && echo "OK: non-empty"
grep -E '^(background|foreground|color0)' kitty/themes/dark.conf | head -3
```

Expected: "OK: non-empty" plus at least one matching color directive.

- [ ] **Step 5: Commit**

```bash
git add kitty/themes/dark.conf
git commit -m "feat(kitty): vendor kanagawabones dark theme"
```

If the pre-commit hook blocks asking to review docs: confirm no docs need updating (this commit only adds a vendored file with no user-facing surface), then re-run the same commit command.

---

## Task 2: Vendor the light theme file

**Files:**
- Create: `kitty/themes/light.conf`

- [ ] **Step 1: Download the upstream AtomOneLight theme**

```bash
curl -fsSL https://raw.githubusercontent.com/kovidgoyal/kitty-themes/master/themes/AtomOneLight.conf -o kitty/themes/light.conf
```

- [ ] **Step 2: Add a header comment recording the source**

Edit `kitty/themes/light.conf` and prepend at the very top:

```
# Vendored from https://github.com/kovidgoyal/kitty-themes/blob/master/themes/AtomOneLight.conf
# Closest available match to wezterm.lua scheme_for_appearance('Light') = 'One Light (Gogh)'
# Do not edit — re-download from upstream to update
```

- [ ] **Step 3: Verify the file**

```bash
test -s kitty/themes/light.conf && echo "OK: non-empty"
grep -E '^(background|foreground|color0)' kitty/themes/light.conf | head -3
```

Expected: "OK: non-empty" plus at least one color directive.

- [ ] **Step 4: Commit**

```bash
git add kitty/themes/light.conf
git commit -m "feat(kitty): vendor AtomOneLight light theme"
```

---

## Task 3: Create the current-theme.conf default symlink

**Files:**
- Create: `kitty/themes/current-theme.conf` (symlink → `dark.conf`)

- [ ] **Step 1: Create the symlink**

```bash
cd kitty/themes && ln -sfn dark.conf current-theme.conf && cd ../..
```

- [ ] **Step 2: Verify it's a symlink pointing at dark.conf**

```bash
ls -la kitty/themes/current-theme.conf
```

Expected: output shows `current-theme.conf -> dark.conf`.

- [ ] **Step 3: Verify git tracks the symlink (not the resolved file contents)**

```bash
git status kitty/themes/current-theme.conf
git ls-files --stage kitty/themes/ 2>/dev/null
```

After `git add`, the staged file should have mode `120000` (symlink), not `100644` (regular file).

- [ ] **Step 4: Commit**

```bash
git add kitty/themes/current-theme.conf
git commit -m "feat(kitty): add current-theme symlink defaulting to dark"
```

Verify the commit recorded a symlink:

```bash
git show HEAD --stat
git ls-tree HEAD kitty/themes/current-theme.conf
```

Expected: the `git ls-tree` line starts with `120000` (symlink mode).

---

## Task 4: Write the theme-sync.sh script

**Files:**
- Create: `kitty/theme-sync.sh`

- [ ] **Step 1: Write the script**

Create `kitty/theme-sync.sh` with this exact content:

```bash
#!/usr/bin/env bash
#
# Sync kitty theme with current macOS appearance.
#
# Reads `defaults read -g AppleInterfaceStyle` (returns "Dark" in dark mode,
# errors out in light mode), then atomically swaps the
# kitty/themes/current-theme.conf symlink to point at dark.conf or light.conf,
# and finally calls `kitty @ load-config` to live-reload any running kitty
# instances.
#
# Safe to run when kitty is not yet installed or no kitty windows exist —
# the load-config call is best-effort and failure is non-fatal.

set -eu

# Resolve the directory containing this script, even when called via symlink.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
THEMES_DIR="$SCRIPT_DIR/themes"

if [ ! -d "$THEMES_DIR" ]; then
  echo "theme-sync: themes directory not found at $THEMES_DIR" >&2
  exit 1
fi

# Detect macOS appearance. The defaults command exits non-zero in light mode,
# so we tolerate the error and treat absence of the key as "light".
if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
  TARGET="dark.conf"
else
  TARGET="light.conf"
fi

# Atomic symlink swap: ln -sfn replaces the existing symlink in place.
ln -sfn "$TARGET" "$THEMES_DIR/current-theme.conf"

# Best-effort live reload of any running kitty instances. Failure is fine —
# kitty might not be installed yet, remote control might be disabled, or no
# windows might be open.
if command -v kitty >/dev/null 2>&1; then
  kitty @ load-config >/dev/null 2>&1 || true
fi
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x kitty/theme-sync.sh
```

- [ ] **Step 3: Verify shebang and executable bit**

```bash
ls -la kitty/theme-sync.sh
head -1 kitty/theme-sync.sh
```

Expected: file mode includes `x` for owner (e.g. `-rwxr-xr-x`); first line is `#!/usr/bin/env bash`.

- [ ] **Step 4: Run the script and verify it updates the symlink**

```bash
./kitty/theme-sync.sh
ls -la kitty/themes/current-theme.conf
```

Expected: no errors. The symlink target should match current macOS appearance — if your system is in dark mode, it points to `dark.conf`; if light, `light.conf`. (You can check current appearance with `defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light`.)

- [ ] **Step 5: Verify the script handles the kitty-not-installed case gracefully**

If kitty is not yet installed (`command -v kitty` returns nothing), the script should still complete with exit code 0:

```bash
./kitty/theme-sync.sh; echo "exit=$?"
```

Expected: `exit=0`.

- [ ] **Step 6: Run shellcheck if available**

```bash
command -v shellcheck >/dev/null && shellcheck kitty/theme-sync.sh || echo "shellcheck not installed, skipping"
```

Expected: no warnings, or "shellcheck not installed, skipping".

- [ ] **Step 7: Commit**

```bash
git add kitty/theme-sync.sh
git commit -m "feat(kitty): add theme-sync script for dark/light auto-switching"
```

The script preserves its executable bit because git tracks the mode bit on first add.

---

## Task 5: Write the main kitty.conf

**Files:**
- Create: `kitty/kitty.conf`

- [ ] **Step 1: Write the config file**

Create `kitty/kitty.conf` with this exact content:

```conf
# kitty.conf — mirrors the wezterm.lua setup at the repo root.
#
# Theme: included via kitty/themes/current-theme.conf, which is a symlink
# managed by kitty/theme-sync.sh and swapped on shell startup via zshrc.

# ─── Font ─────────────────────────────────────────────────────────────────────
# Monaco DemiBold matches wezterm's font_with_fallback({ family = 'Monaco', weight = 'DemiBold' }).
# kitty's font picker accepts a PostScript-style style name.
font_family      family="Monaco" style="DemiBold"
bold_font        auto
italic_font      auto
bold_italic_font auto

font_size 13.0

# wezterm: line_height = 1.2 → kitty: 120% cell height
modify_font cell_height 120%

# Use JetBrainsMono Nerd Font Mono for icon glyphs (Powerline/Nerd Font ranges).
# Apple Color Emoji and CJK fall back through the system fontconfig automatically.
symbol_map U+E0A0-U+E0A3,U+E0B0-U+E0BF,U+E0C0-U+E0C7 JetBrainsMono Nerd Font Mono
symbol_map U+E5FA-U+E631,U+F000-U+F2E0,U+F300-U+F32F JetBrainsMono Nerd Font Mono

disable_ligatures never

# ─── Cursor ───────────────────────────────────────────────────────────────────
# wezterm: BlinkingBar at 600ms
cursor_shape          beam
cursor_blink_interval 0.6

# ─── Scrollback ───────────────────────────────────────────────────────────────
scrollback_lines 10000

# ─── Window ───────────────────────────────────────────────────────────────────
# wezterm padding: left=10, right=10, top=40, bottom=8
# kitty has no integrated tab strip in the title bar, so the wezterm 40 top is
# unnecessary. Order is: top right bottom left.
window_padding_width 8 10 8 10

# wezterm: hide_tab_bar_if_only_one_tab → kitty equivalent
tab_bar_min_tabs 2
tab_title_template "{cwd}"

# wezterm: inactive_pane_hsb { saturation = 0.9, brightness = 0.9 }
# kitty has no separate saturation/brightness; closest is text alpha.
inactive_text_alpha 0.9

# ─── macOS window decorations ─────────────────────────────────────────────────
# wezterm: INTEGRATED_BUTTONS|RESIZE
hide_window_decorations  titlebar-only
macos_show_window_title_in none

# ─── Layouts ──────────────────────────────────────────────────────────────────
# `splits` is required for the Cmd+Shift+| / Cmd+Shift+arrow split bindings.
# `stack` provides a one-pane-at-a-time fullscreen mode (like tmux zoom).
enabled_layouts splits,stack

# ─── Mouse ────────────────────────────────────────────────────────────────────
# Cmd+click opens links (matches wezterm).
mouse_map cmd+left release grabbed,ungrabbed mouse_click_url

# ─── Remote control ───────────────────────────────────────────────────────────
# Required so theme-sync.sh can call `kitty @ load-config` for live reload.
allow_remote_control yes
listen_on unix:/tmp/kitty-$USER

# ─── Keybindings ──────────────────────────────────────────────────────────────
# Wezterm parity. Cmd+P (command palette) intentionally dropped — kitty has no
# equivalent, see docs/superpowers/specs/2026-04-07-kitty-config-design.md.

# IDE-like 3-pane layout: left half + right top + right bottom 15%
map cmd+shift+\ combine : launch --location=vsplit --bias=50 --cwd=current : launch --location=hsplit --bias=15 --cwd=current

# Simple splits
map cmd+shift+right launch --location=vsplit --cwd=current
map cmd+shift+down  launch --location=hsplit --cwd=current

# Close current pane (with confirmation)
map cmd+shift+x close_window_with_confirmation

# ─── Theme (auto-switched by theme-sync.sh) ───────────────────────────────────
include themes/current-theme.conf
```

**Note on the Cmd+Shift+\| binding:** kitty's keybinding syntax uses `\` to denote the `|` character on a US keyboard (Shift+\ = `|`). Hence `cmd+shift+\` rather than `cmd+shift+|`.

- [ ] **Step 2: Verify the file was written and has the expected sections**

```bash
test -s kitty/kitty.conf && echo "OK: non-empty"
grep -c "^map " kitty/kitty.conf
grep -c "^font_family" kitty/kitty.conf
grep "include themes/current-theme.conf" kitty/kitty.conf
```

Expected: "OK: non-empty"; map count = 4 (the four keybindings); `font_family` count = 1; the include line is present.

- [ ] **Step 3: Validate kitty parses the config (only if kitty is installed)**

```bash
if command -v kitty >/dev/null 2>&1; then
  kitty +runpy 'from kitty.conf.parse import KittyConfigParser; print("kitty available")' 2>/dev/null || \
  kitty --debug-config --config kitty/kitty.conf 2>&1 | head -20
else
  echo "kitty not yet installed — config syntax validation skipped (will validate after Brewfile install)"
fi
```

Expected: either "kitty available" / debug output with no fatal parse errors, or the "skipped" message. If there are parse errors, fix them and re-run.

- [ ] **Step 4: Commit**

```bash
git add kitty/kitty.conf
git commit -m "feat(kitty): add main kitty.conf mirroring wezterm setup"
```

---

## Task 6: Add the Makefile target

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add the `KITTY_CONFIG_DIR` variable**

Open `Makefile` and add this line in the variables block at the top, after the existing `NVIM_CONFIG_DIR := $(HOME)/.config/nvim` line:

Insert (after line 4):

```make
KITTY_CONFIG_DIR := $(HOME)/.config/kitty
```

The variables block (lines 1–8) should now read:

```make
GIT_CONFIG_DIR := $(HOME)/.config/git
DOTFILES_GIT_DIR := $(PWD)/git
STARSHIP_CONFIG_DIR := $(HOME)/.config
NVIM_CONFIG_DIR := $(HOME)/.config/nvim
KITTY_CONFIG_DIR := $(HOME)/.config/kitty
GH_CONFIG_DIR := $(HOME)/.config/gh
CLAUDE_SKILLS_DIR := $(HOME)/.claude/skills
CLAUDE_HOOKS_DIR := $(HOME)/.claude/hooks
CLAUDE_SETTINGS := $(HOME)/.claude/settings.json
```

- [ ] **Step 2: Add `kitty-config-install` to the `.PHONY` declaration**

Find the `.PHONY` line (currently line 10):

```make
.PHONY: git git-install git-local git-check wezterm-config-install docker-config-install nvim-config-install gh-config-install starship-config-install zsh-install brew-install brew-dump claude-skills-install claude-hooks-install
```

Add `kitty-config-install` immediately after `wezterm-config-install`:

```make
.PHONY: git git-install git-local git-check wezterm-config-install kitty-config-install docker-config-install nvim-config-install gh-config-install starship-config-install zsh-install brew-install brew-dump claude-skills-install claude-hooks-install
```

- [ ] **Step 3: Add the `kitty-config-install` target**

Insert this target immediately after the existing `wezterm-config-install` target (after line 51, before `docker-config-install`):

```make
kitty-config-install:
	@echo "→ Installing kitty config"
	mkdir -p $(HOME)/.config
	ln -sfn $(PWD)/kitty $(KITTY_CONFIG_DIR)
	@$(PWD)/kitty/theme-sync.sh || true
	@echo "✓ kitty config installed"
```

**Important:** Makefile recipe lines must be indented with **a real tab character**, not spaces. After editing, verify:

```bash
grep -P "^\t" Makefile | head -5
```

Expected: shows tab-indented recipe lines (the `→` arrow characters at the start of each).

- [ ] **Step 4: Run `make kitty-config-install` and verify**

```bash
make kitty-config-install
```

Expected output:

```
→ Installing kitty config
mkdir -p /Users/ivan_kalinichenko/.config
ln -sfn /Users/ivan_kalinichenko/Dev/Personal/dotfiles/kitty /Users/ivan_kalinichenko/.config/kitty
✓ kitty config installed
```

(`theme-sync.sh` runs silently; no output unless it fails.)

- [ ] **Step 5: Verify the symlink was created correctly**

```bash
ls -la ~/.config/kitty
```

Expected: `~/.config/kitty -> /Users/ivan_kalinichenko/Dev/Personal/dotfiles/kitty` (or wherever the repo lives).

- [ ] **Step 6: Verify idempotency — run install a second time**

```bash
make kitty-config-install
ls -la ~/.config/kitty
```

Expected: same output, no nested symlink (`~/.config/kitty/kitty` should NOT exist as an additional symlink).

- [ ] **Step 7: Verify the current-theme.conf symlink is live and correct**

```bash
ls -la ~/.config/kitty/themes/current-theme.conf
defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light
```

Expected: the symlink target matches the current appearance (`dark.conf` if Dark, `light.conf` otherwise).

- [ ] **Step 8: Commit**

```bash
git add Makefile
git commit -m "feat(make): add kitty-config-install target"
```

---

## Task 7: Add the zshrc theme-sync hook

**Files:**
- Modify: `zsh/zshrc`

- [ ] **Step 1: Add the hook line to `zsh/zshrc`**

Append these two lines to the end of `zsh/zshrc` (after the existing bun completions line):

```sh

# Sync kitty theme with macOS appearance (runs detached; harmless if kitty is not installed)
[ -x "$HOME/.config/kitty/theme-sync.sh" ] && "$HOME/.config/kitty/theme-sync.sh" &!
```

The full file should now end with:

```sh
# bun completions
[ -s "/Users/ivan_kalinichenko/.bun/_bun" ] && source "/Users/ivan_kalinichenko/.bun/_bun"

# Sync kitty theme with macOS appearance (runs detached; harmless if kitty is not installed)
[ -x "$HOME/.config/kitty/theme-sync.sh" ] && "$HOME/.config/kitty/theme-sync.sh" &!
```

`&!` is zsh-specific syntax meaning "background and disown" — the script won't appear in `jobs` output.

- [ ] **Step 2: Verify zshrc parses without errors**

```bash
zsh -n zsh/zshrc && echo "OK: zshrc parses"
```

Expected: "OK: zshrc parses". `-n` checks syntax without executing.

- [ ] **Step 3: Source the file in a subshell to confirm runtime correctness**

```bash
zsh -c 'source zsh/zshrc; echo "OK: sourced"' 2>&1 | tail -3
```

Expected: ends with "OK: sourced". Some non-fatal warnings from oh-my-zsh or plugins are acceptable; a hard error is not.

- [ ] **Step 4: Commit**

```bash
git add zsh/zshrc
git commit -m "feat(zsh): run kitty theme-sync on shell startup"
```

---

## Task 8: Add kitty to the Brewfile

**Files:**
- Modify: `Brewfile`

- [ ] **Step 1: Verify kitty is not already in the Brewfile**

```bash
grep -n '"kitty"' Brewfile || echo "not present"
```

Expected: "not present".

- [ ] **Step 2: Add `cask "kitty"` after `cask "ghostty"` (alphabetical)**

The current Brewfile cask block (lines 26–34) is:

```
cask "codex"
cask "font-fira-code"
cask "font-iosevka"
cask "font-jetbrains-mono"
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
cask "kap"
cask "yt-dlp"
cask "wezterm"
```

Insert `cask "kitty"` between `cask "ghostty"` and `cask "kap"`:

```
cask "codex"
cask "font-fira-code"
cask "font-iosevka"
cask "font-jetbrains-mono"
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
cask "kitty"
cask "kap"
cask "yt-dlp"
cask "wezterm"
```

- [ ] **Step 3: Verify the Brewfile is well-formed**

```bash
grep '"kitty"' Brewfile
brew bundle check --file=Brewfile --no-upgrade 2>&1 | tail -5 || true
```

Expected: the grep finds the new line. `brew bundle check` may report kitty as missing on this machine — that's expected and fine; we're checking syntax not installation state.

- [ ] **Step 4: Commit**

```bash
git add Brewfile
git commit -m "feat(brew): add kitty cask"
```

---

## Task 9: Install kitty and verify the config

**Files:** none (verification only — but this is the moment kitty actually gets installed and parses the config)

- [ ] **Step 1: Install kitty via brew**

```bash
brew install --cask kitty
```

Expected: kitty.app is installed in `/Applications`. If already installed (e.g. from a previous attempt), brew will report so and exit 0.

- [ ] **Step 2: Verify kitty is on PATH**

```bash
which kitty
kitty --version
```

Expected: a path under `/opt/homebrew/bin/kitty` (or similar) and a version string. If `which kitty` is empty but the app exists, the kitty CLI may need a separate symlink — re-check the brew cask docs.

- [ ] **Step 3: Validate the config parses cleanly**

```bash
kitty --debug-config 2>&1 | head -30
```

Expected: a dump of the resolved config including font, color, and keybinding sections. **No** lines containing `Error parsing` or `Unknown option`.

- [ ] **Step 4: Open kitty and visually verify**

```bash
open -na kitty
```

Expected:
- Theme matches current macOS appearance (dark = kanagawabones, light = AtomOneLight)
- Monaco DemiBold font at 13pt with 1.2 line height
- Title bar is integrated (no separate title strip)
- Beam cursor that blinks

- [ ] **Step 5: Test split keybindings inside kitty**

In the running kitty window, press:
- `Cmd+Shift+→` — should create a vertical split
- `Cmd+Shift+↓` — should create a horizontal split
- `Cmd+Shift+X` — should close the current pane (with confirmation)
- `Cmd+Shift+|` (i.e. `Cmd+Shift+\`) — should produce the IDE 3-pane layout

If `Cmd+Shift+|` produces the right geometry but with inverted percentages (e.g. the bottom strip is the big one), edit `kitty/kitty.conf` and flip the bias values:
- `--bias=50` → keep as 50 (50/50 is symmetric)
- `--bias=15` → change to `--bias=85`

Then save, run `kitty @ load-config`, and re-test. **If you make this fix, commit it as a separate small commit:**

```bash
git add kitty/kitty.conf
git commit -m "fix(kitty): correct bias values for IDE layout binding"
```

- [ ] **Step 6: Test the theme switcher**

Toggle macOS appearance (System Settings → Appearance, or `osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'`), then in kitty:

```bash
~/.config/kitty/theme-sync.sh
```

Expected: the running kitty window's colors switch to match the new appearance (no restart needed). Verify `~/.config/kitty/themes/current-theme.conf` now points at the other theme file.

- [ ] **Step 7: Test the zsh hook**

Open a brand new kitty window. The new shell should automatically run `theme-sync.sh` in the background. Verify by opening the new window after toggling appearance again — the colors should be correct from the first paint.

- [ ] **Step 8: No commit for this task**

This is verification-only. If steps 1–7 pass, proceed to Task 10. If any step fails, diagnose, fix the relevant config file, commit the fix, and re-run the failing step.

---

## Task 10: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the install command line to the Installation Commands section**

Find the existing WezTerm install line in `CLAUDE.md`:

```
# Terminal emulator
make wezterm-config-install   # Symlink wezterm.lua to ~/.wezterm.lua
```

Replace it with:

```
# Terminal emulators
make wezterm-config-install   # Symlink wezterm.lua to ~/.wezterm.lua
make kitty-config-install     # Symlink kitty/ to ~/.config/kitty
```

- [ ] **Step 2: Add a "Kitty Configuration" section under "Architecture & Key Patterns"**

Find the existing `### WezTerm Configuration` section in `CLAUDE.md`. Add this new section **immediately after** it (before the next `##` section):

```markdown
### Kitty Configuration

Multi-file configuration in `kitty/`, mirroring the wezterm setup so the user can swap terminals without losing muscle memory:

```
kitty/
├── kitty.conf              # Main config — font, cursor, padding, scrollback, layouts, keybindings, theme include
├── theme-sync.sh           # Reads macOS appearance, swaps current-theme.conf symlink, calls `kitty @ load-config`
└── themes/
    ├── current-theme.conf  # symlink → dark.conf or light.conf (managed by theme-sync.sh)
    ├── dark.conf           # vendored kanagawabones from kovidgoyal/kitty-themes
    └── light.conf          # vendored AtomOneLight from kovidgoyal/kitty-themes
```

**Theme switching mechanism:** kitty has no reactive equivalent to wezterm's `window-config-reloaded` event, so the dark/light auto-switch is implemented as a symlink swap:

1. `kitty.conf` ends with `include themes/current-theme.conf`
2. `kitty/theme-sync.sh` reads `defaults read -g AppleInterfaceStyle`, points `current-theme.conf` at the right file, then calls `kitty @ load-config` for live reload
3. `zsh/zshrc` runs the script in the background (`&!`) on every shell startup so each new kitty window picks up the right theme
4. `kitty.conf` enables `allow_remote_control yes` so the live reload works

**Notable keybindings:**
- `Cmd+Shift+|` — IDE-like 3-pane layout (left half + right top + right bottom 15%) via `combine : launch ... : launch ...`
- `Cmd+Shift+→` / `Cmd+Shift+↓` — split right / down
- `Cmd+Shift+X` — close pane

The wezterm `Cmd+P` command palette has no kitty equivalent and is intentionally dropped.

Splits require `enabled_layouts splits,stack` in `kitty.conf` — kitty's default layout doesn't support them.
```

(Note: in the inline code block above, the inner triple-backticks are kept literal — paste the section as-is into CLAUDE.md, including the triple-backtick fence around the directory tree.)

- [ ] **Step 3: Verify the section was added**

```bash
grep -c "Kitty Configuration" CLAUDE.md
grep -c "kitty-config-install" CLAUDE.md
```

Expected: 1 section header, 1 install command line.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): document kitty config setup and theme switching"
```

---

## Task 11: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `kitty/` to the Contents list**

Find this line in the Contents section:

```markdown
- **wezterm.lua** - WezTerm terminal emulator configuration
```

Add immediately after it:

```markdown
- **kitty/** - Kitty terminal emulator configuration with auto dark/light theme switching
```

The relevant section should now read:

```markdown
- **wezterm.lua** - WezTerm terminal emulator configuration
- **kitty/** - Kitty terminal emulator configuration with auto dark/light theme switching
- **alacritty/** - Alacritty terminal emulator configuration with theme variants
```

- [ ] **Step 2: Add a "Kitty" install section after the WezTerm section**

Find the existing `### WezTerm` section (around line 76). After the entire WezTerm section (which ends with the bullet list of features), add this new section before `### Neovim`:

```markdown
### Kitty

```bash
make kitty-config-install
```

Symlinks `kitty/` to `~/.config/kitty/` and runs `kitty/theme-sync.sh` once so the theme symlink points at the current macOS appearance.

#### Kitty Features

- Monaco DemiBold font with JetBrainsMono Nerd Font fallback for icon glyphs
- Automatic dark/light theme switching (kanagawabones / AtomOneLight) via `theme-sync.sh` triggered from `zshrc`
- IDE-like 3-pane layout binding on `Cmd+Shift+|` (left half + right top + right bottom 15%)
- Native pane splits via the `splits` layout — no tmux required
- Beam cursor blinking at 600ms (matches wezterm)
- Integrated macOS title bar
```

(Note: as in Task 10, the inner triple-backtick `bash` block is literal — paste as-is.)

- [ ] **Step 3: Verify the section was added**

```bash
grep -c "### Kitty" README.md
grep -c "kitty-config-install" README.md
grep -c "kitty/\*\*" README.md
```

Expected: 1 section header, 1 install command, 1 Contents bullet.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): document kitty install and features"
```

---

## Task 12: Final integration check

**Files:** none (end-to-end verification)

- [ ] **Step 1: Verify the full git log on the branch**

```bash
git log --oneline main..HEAD
```

Expected: ~10 commits (one per implementation task plus the spec commit), all on `feat/kitty-config`.

- [ ] **Step 2: Verify nothing is uncommitted**

```bash
git status
```

Expected: working tree clean, no untracked files in `kitty/` or modifications elsewhere.

- [ ] **Step 3: Run the install one more time from a clean state**

```bash
rm -f ~/.config/kitty
make kitty-config-install
ls -la ~/.config/kitty
ls -la ~/.config/kitty/themes/current-theme.conf
```

Expected: clean install, symlink created, theme symlink correct.

- [ ] **Step 4: Open kitty and run through the verification plan from the spec**

For each item in the spec's "Verification plan" section, confirm it passes:

1. ✅ `make kitty-config-install` succeeds with a clean `~/.config/kitty`
2. ✅ Re-running `make kitty-config-install` is idempotent (no nested symlinks)
3. ✅ `current-theme.conf` symlink matches macOS appearance
4. ✅ Launching kitty applies the correct theme on first open
5. ✅ `Cmd+Shift+|` produces the IDE 3-pane layout
6. ✅ `Cmd+Shift+→` and `Cmd+Shift+↓` create simple splits
7. ✅ Toggling macOS appearance + opening a new kitty window picks up the new theme

If anything fails, fix it, commit the fix, re-run.

- [ ] **Step 5: No commit for this task**

End of plan. The branch is ready for review / merge to `main`.

---

## Summary of commits

By the end of this plan, `feat/kitty-config` should contain (approximately):

1. `docs(kitty): add design spec for kitty terminal config` *(already done)*
2. `feat(kitty): vendor kanagawabones dark theme`
3. `feat(kitty): vendor AtomOneLight light theme`
4. `feat(kitty): add current-theme symlink defaulting to dark`
5. `feat(kitty): add theme-sync script for dark/light auto-switching`
6. `feat(kitty): add main kitty.conf mirroring wezterm setup`
7. `feat(make): add kitty-config-install target`
8. `feat(zsh): run kitty theme-sync on shell startup`
9. `feat(brew): add kitty cask`
10. `docs(claude): document kitty config setup and theme switching`
11. `docs(readme): document kitty install and features`

Plus possibly one `fix(kitty): correct bias values for IDE layout binding` commit if Task 9 step 5 reveals inverted bias semantics.
