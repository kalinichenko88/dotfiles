# dotfiles

My personal configuration files for macOS.

## Contents

- **Brewfile** - Homebrew packages and casks
- **zsh/** - Zsh configuration with modular structure
- **git/** - Git configuration with separate profiles for personal and work
- **docker/** - Docker CLI configuration for Colima
- **wezterm.lua** - WezTerm terminal emulator configuration
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

### SSH Remote (`ssh-remote/`)

Typing `ssh <host>` in an interactive terminal automatically ships a self-contained Neovim + custom shell prompt to the remote host, sets the WezTerm tab title to the host name, and restores everything on exit.

```bash
make ssh-remote-install   # vendor plugins + make bootstrap executable
```

#### How it works

`zsh/ssh-remote.zsh` is auto-sourced by `zshrc` and defines an `ssh()` wrapper. The wrapper intercepts only the bare form — `ssh [user@]<host>` with no flags or remote command. Everything else (port forwarding, remote commands, non-TTY) passes straight through to `command ssh`.

For intercepted connections, the bundle is rsynced to `~/.dotfiles-remote/bundle/` on the server via a shared ControlMaster (so password/MFA hosts prompt only once). State files are isolated under `~/.dotfiles-remote/state/`; the server's own rc files are never touched — prompt and aliases are injected only for the session via `ZDOTDIR` / `bash --init-file`.

On the server, `v` / `vim` / `vi` open the portable Neovim (mini.nvim, no LSP). If Neovim is absent, the aliases fall back to the system `vim` or `vi`.

#### Usage

```bash
ssh <host>                  # intercepted: ships bundle, opens remote shell
SSH_NO_BUNDLE=1 ssh <host>  # bypass wrapper entirely (plain ssh)
command ssh <host>          # also bypasses wrapper

# on the remote host:
v file.ts                   # open in portable nvim
vim file.ts                 # same
```

#### Make targets

| Target | Description |
|--------|-------------|
| `make ssh-remote-vendor` | Vendor plugins listed in `ssh-remote/plugins.txt` |
| `make ssh-remote-install` | Vendor plugins + ensure `bootstrap.sh` is executable |
| `make ssh-remote-test` | Run guard / profile-select / nvim smoke tests |
| `make ssh-remote-clean-host HOST=<host>` | Remove `~/.dotfiles-remote` from a server |

> **Public-repo rule:** no hostnames, IPs, or per-host data belong in tracked files. Put per-host tweaks in the gitignored `zsh/local.zsh`.

## License

MIT
