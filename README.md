# dotfiles

My personal configuration files for macOS.

## Contents

- **Brewfile** - Homebrew packages and casks
- **git/** - Git configuration with separate profiles for personal and work
- **docker/** - Docker CLI configuration for Colima
- **wezterm.lua** - WezTerm terminal emulator configuration
- **nvim/** - Neovim configuration with lazy.nvim plugin manager
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

### WezTerm

```bash
make wezterm-config-install
```

Symlinks `wezterm.lua` to `~/.wezterm.lua`.

#### WezTerm Features

- WebGpu rendering at 120 FPS
- JetBrains Mono NL font with Menlo fallback
- Automatic dark/light theme switching (OneDark/One Light)
- Native macOS fullscreen and integrated window buttons
- Blinking bar cursor

### Neovim

```bash
make nvim-config-install
```

Symlinks `nvim/` directory to `~/.config/nvim`.

See [nvim/README.md](nvim/README.md) for full documentation, keybindings, and setup instructions.

### Docker

```bash
make docker-config-install
```

Copies `docker/config.json` to `~/.docker/config.json`. Configured for [Colima](https://github.com/abiosoft/colima) with Homebrew CLI plugins.

## License

MIT
