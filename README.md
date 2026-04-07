# dotfiles

My personal configuration files for macOS.

## Contents

- **Brewfile** - Homebrew packages and casks
- **zsh/** - Zsh configuration with modular structure
- **git/** - Git configuration with separate profiles for personal and work
- **docker/** - Docker CLI configuration for Colima
- **wezterm.lua** - WezTerm terminal emulator configuration
- **kitty/** - Kitty terminal emulator configuration with auto dark/light theme switching
- **alacritty/** - Alacritty terminal emulator configuration with theme variants
- **nvim/** - Neovim configuration with lazy.nvim plugin manager
- **gh/** - GitHub CLI configuration
- **starship/** - Starship prompt configuration
- **claude/** - Claude Code skills (create-post) and hooks (check-docs-before-commit)
- **.editorconfig** - Editor configuration for consistent coding style

## Installation

### Homebrew

```bash
make brew-install
```

Installs all packages and casks from `Brewfile`.

To update the Brewfile with currently installed packages:

```bash
make brew-dump
```

### Git

```bash
make git-install
```

This will:
1. Create `~/.config/git/` directory
2. Symlink git config files
3. Create `gitconfig-work` and `gitconfig-local` from examples if they don't exist

After installation, edit `git/gitconfig-work` with your work email.

#### Git Configuration Structure

| File | Purpose |
|------|---------|
| `gitconfig` | Main config with user name and conditional includes |
| `gitconfig-personal` | Email for `~/Dev/Personal/` repositories |
| `gitconfig-work` | Email for `~/Dev/Work/` repositories (gitignored) |
| `gitconfig-local` | Machine-specific overrides like GPG signing (gitignored) |

Verify your configuration:
```bash
make git-check
```

#### Delta Theme Switching

`delta` theme switches automatically between:
- `OneHalfLight` for light mode
- `OneHalfDark` for dark mode

Priority:
1. `DELTA_THEME_MODE` environment variable (`light` / `dark`)
2. macOS appearance (`defaults read -g AppleInterfaceStyle`)

This applies to both:
- normal git pager output (`core.pager`)
- interactive hunk mode (`interactive.diffFilter`)

### WezTerm

```bash
make wezterm-config-install
```

Symlinks `wezterm.lua` to `~/.wezterm.lua`.

#### WezTerm Features

- WebGpu rendering at 120 FPS
- Monaco font with Menlo and Nerd Font fallbacks
- Automatic dark/light theme switching (OneDark/One Light)
- Exports `BAT_THEME` and `DELTA_THEME_MODE` so `delta` follows terminal theme
- Native macOS fullscreen and integrated window buttons
- Blinking bar cursor

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

### Neovim

```bash
make nvim-config-install
```

Symlinks `nvim/` directory to `~/.config/nvim`.

See [nvim/README.md](nvim/README.md) for full documentation, keybindings, and setup instructions.

### GitHub CLI

```bash
make gh-config-install
```

Symlinks `gh/config.yml` to `~/.config/gh/config.yml`. Configured with SSH protocol, Neovim as editor, and delta as pager.

After installation, authenticate with `gh auth login`.

### Zsh

```bash
make zsh-install
```

Symlinks `zsh/zshrc` to `~/.zshrc`.

#### Zsh Configuration Structure

| File | Purpose |
|------|---------|
| `zshrc` | Entry point — sources all `.zsh` files from the directory |
| `options.zsh` | Oh My Zsh setup, theme, plugins, editor |
| `path.zsh` | PATH entries for Homebrew, nvm, bun, Python, etc. |
| `aliases.zsh` | Custom aliases |
| `starship.zsh` | Starship prompt init |
| `local.zsh` | Machine-specific overrides (gitignored, create from `local.zsh.example`) |

### Starship

```bash
make starship-config-install
```

Symlinks `starship/starship.toml` to `~/.config/starship.toml`. Configured with increased command timeout (1000ms) to prevent slow plugin warnings.

### Docker

```bash
make docker-config-install
```

Copies `docker/config.json` to `~/.docker/config.json`. Configured for [Colima](https://github.com/abiosoft/colima) with Homebrew CLI plugins.

### Claude Code Skills

```bash
make claude-skills-install
```

Symlinks skill directories from `claude/skills/` to `~/.claude/skills/`.

Available skills:
- **create-post** - Creates English blog posts from rough Russian technical drafts for kalinichenko.dev

### Claude Code Hooks

```bash
make claude-hooks-install
```

Symlinks hook scripts from `claude/hooks/` to `~/.claude/hooks/` and merges hook configuration into `~/.claude/settings.json`.

Available hooks:
- **check-docs-before-commit** - Blocks commits until Claude reviews documentation files (CLAUDE.md, README.md) for accuracy

## License

MIT
