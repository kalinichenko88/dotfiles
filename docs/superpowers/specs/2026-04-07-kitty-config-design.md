# Kitty Terminal Configuration

**Status:** Draft for review
**Date:** 2026-04-07
**Branch:** `feat/kitty-config`

## Goal

Add a kitty terminal configuration to the dotfiles repository that mirrors the existing wezterm setup (font, theme switching, keybindings, splits) so the user can switch terminals without losing muscle memory or visual consistency. Provide a `make kitty-config-install` target that symlinks the config into `~/.config/kitty`.

## Non-goals

- Replacing wezterm. Both configs coexist; the user picks at runtime.
- Migrating wezterm-specific features that have no kitty equivalent (e.g. command palette).
- Theme parity at the pixel level. "Close enough" using vendored community themes is acceptable.

## Directory layout

```
kitty/
├── kitty.conf              # main config (font, cursor, padding, scrollback, layouts, keybindings, theme include)
├── theme-sync.sh           # reads macOS appearance, swaps current-theme.conf symlink, calls `kitty @ load-config`
└── themes/
    ├── current-theme.conf  # symlink → dark.conf or light.conf, swapped by theme-sync.sh
    ├── dark.conf           # vendored from kovidgoyal/kitty-themes (kanagawa.conf)
    └── light.conf          # vendored from kovidgoyal/kitty-themes (Atom_One_Light.conf)
```

The whole `kitty/` directory is symlinked to `~/.config/kitty/` (matches the `nvim/` install pattern). Themes are vendored as static files so installation is offline-safe.

## Settings (translated from wezterm.lua)

| Concern | wezterm | kitty |
|---|---|---|
| Primary font | Monaco DemiBold | `font_family` directive set to Monaco's DemiBold face (exact syntax — `family="Monaco" style="DemiBold"` vs PostScript name — chosen during implementation based on what kitty's font picker accepts on this machine) |
| Font fallbacks | Menlo, JetBrainsMono Nerd Font, Symbols Nerd Font, Apple Color Emoji, PingFang SC | `symbol_map` ranges pointing to JetBrainsMono Nerd Font Mono for icon glyphs; kitty uses the system fontconfig for emoji/CJK fallback automatically |
| Font size | 13.0 | `font_size 13.0` |
| Line height | 1.2 | `modify_font cell_height 120%` |
| Cursor style | BlinkingBar, 600ms | `cursor_shape beam`, `cursor_blink_interval 0.6` |
| Scrollback | 10000 lines | `scrollback_lines 10000` |
| Tab bar | hide if only one tab | `tab_bar_min_tabs 2` |
| Window decorations | INTEGRATED_BUTTONS\|RESIZE | `hide_window_decorations titlebar-only`, `macos_show_window_title_in none` |
| Window padding | left/right 10, top 40, bottom 8 | `window_padding_width 8 10 8 10` (kitty has no integrated tab strip in the title bar, so the wezterm 40px top padding is unnecessary) |
| Tab title | current directory name | `tab_title_template "{cwd}"` |
| Cmd+click opens link | wezterm built-in | `mouse_map cmd+left release grabbed,ungrabbed mouse_click_url` |
| Inactive pane dim | hsb 0.9/0.9 | `inactive_text_alpha 0.9` (closest equivalent — kitty doesn't have separate saturation/brightness) |
| Layouts available | n/a (wezterm uses panes natively) | `enabled_layouts splits,stack` |

## Theme switching

Kitty has no reactive equivalent to wezterm's `window-config-reloaded` event. The chosen approach is **symlink swap + zsh hook + remote control reload**:

1. `kitty.conf` ends with `include themes/current-theme.conf`.
2. `kitty/theme-sync.sh`:
   - Reads `defaults read -g AppleInterfaceStyle 2>/dev/null` (returns `Dark` or errors out for light mode).
   - Determines target file (`dark.conf` or `light.conf`).
   - Atomically swaps `themes/current-theme.conf` symlink: `ln -sfn dark.conf themes/current-theme.conf`.
   - Calls `kitty @ load-config` to live-reload all running kitty windows. Failure here is non-fatal (kitty might not be running yet, or remote control might be off).
3. `zsh/zshrc` runs the script in the background on every shell startup so each new kitty window/tab picks up the right theme:
   ```sh
   [ -x "$HOME/.config/kitty/theme-sync.sh" ] && "$HOME/.config/kitty/theme-sync.sh" &!
   ```
4. `kitty.conf` enables `allow_remote_control yes` so `kitty @ load-config` works.

**Trade-off accepted:** the theme updates on shell startup, not the instant macOS appearance changes. To get the new theme during a long-running session, the user opens a new kitty window/tab (or runs `theme-sync.sh` manually). This matches the user's wezterm muscle memory closely enough.

## Theme files

Vendored from `kovidgoyal/kitty-themes` (official, MIT-licensed):

- `themes/dark.conf` ← `themes/kanagawa.conf` from kitty-themes (closest match to wezterm's `kanagawabones`)
- `themes/light.conf` ← `themes/Atom_One_Light.conf` from kitty-themes (closest match to wezterm's `One Light (Gogh)`)

Files are copied verbatim with a header comment noting the source and SHA. No hand-tuning — accepting "close enough" parity.

## Keybindings

| Action | Binding | kitty config |
|---|---|---|
| IDE-like 3-pane layout (left half + right top + right bottom 15%) | `Cmd+Shift+\|` | `map cmd+shift+\| combine : launch --location=vsplit --bias=50 --cwd=current : launch --location=hsplit --bias=15 --cwd=current` |
| Split right (vertical) | `Cmd+Shift+→` | `map cmd+shift+right launch --location=vsplit --cwd=current` |
| Split down (horizontal) | `Cmd+Shift+↓` | `map cmd+shift+down launch --location=hsplit --cwd=current` |
| Close current pane (with confirmation) | `Cmd+Shift+X` | `map cmd+shift+x close_window_with_confirmation` |
| ~~Command palette~~ | ~~`Cmd+P`~~ | dropped — no kitty equivalent |

`enabled_layouts splits,stack` is required for split bindings to work. Default layout will be `splits`.

**Bias semantics caveat:** kitty's `--bias` parameter for `launch` is documented thinly. The values above (`50` and `15`) assume bias = "percentage of parent assigned to the new window". If empirical testing shows the semantics are inverted, the values flip to `50`/`85` — same conceptual layout. This is a one-character fix during implementation.

## Makefile target

Mirrors the `nvim-config-install` pattern:

```make
KITTY_CONFIG_DIR := $(HOME)/.config/kitty

kitty-config-install:
	@echo "→ Installing kitty config"
	mkdir -p $(HOME)/.config
	ln -sfn $(PWD)/kitty $(KITTY_CONFIG_DIR)
	@$(PWD)/kitty/theme-sync.sh || true
	@echo "✓ kitty config installed"
```

- `ln -sfn` — `-n` is critical so a re-install replaces the symlink instead of creating a nested link inside an existing directory
- `theme-sync.sh` runs immediately so `themes/current-theme.conf` points at the right file from first launch
- `|| true` keeps the install non-blocking if the script fails (e.g. kitty not yet installed)
- Add `kitty-config-install` to `.PHONY`

## zshrc integration

One line added to `zsh/zshrc` (location: alongside other startup helpers):

```sh
# Sync kitty theme with macOS appearance (runs detached)
[ -x "$HOME/.config/kitty/theme-sync.sh" ] && "$HOME/.config/kitty/theme-sync.sh" &!
```

`&!` is the zsh shorthand for "background and disown" — keeps the script from showing up in `jobs` output.

## Brewfile

Add `cask "kitty"` if not already present. (Verify during implementation; do not duplicate.)

## Documentation updates

1. **CLAUDE.md** — add a "Kitty Configuration" section under "Architecture & Key Patterns" mirroring the existing "WezTerm Configuration" section. Cover:
   - Directory structure
   - How theme switching works (symlink + zsh hook + remote control)
   - The IDE layout keybinding
   - Reference to the install command
2. **README.md** — add `make kitty-config-install` to the installation steps list.

## Out of scope (will not do)

- Cmd+P command palette substitute
- Hand-tuned theme files matching wezterm pixel-for-pixel
- A `dark-mode-notify` daemon or other reactive theme switcher
- Removing or deprecating the wezterm config

## Open implementation questions (resolve during build, not now)

- Whether `--bias=50` / `--bias=15` produces the expected geometry (may need to flip to 50/85 if kitty's semantics are inverted)
- Whether `kitty-themes` includes both `kanagawa.conf` and `Atom_One_Light.conf` under those exact names (verify upstream; pick closest if names differ)
- Whether `cask "kitty"` is already in the Brewfile (check before adding)

## Verification plan

After implementation:

1. `make kitty-config-install` succeeds with a clean `~/.config/kitty`
2. `make kitty-config-install` succeeds when run a second time (idempotency, no nested symlinks)
3. `ls -la ~/.config/kitty/themes/current-theme.conf` shows a valid symlink to either `dark.conf` or `light.conf` matching current macOS appearance
4. Launching kitty applies the correct theme on first open
5. `Cmd+Shift+\|` produces the IDE 3-pane layout
6. `Cmd+Shift+→` and `Cmd+Shift+↓` create simple splits
7. Toggling macOS appearance + opening a new kitty window picks up the new theme
