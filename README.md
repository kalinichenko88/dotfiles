# dotfiles

My personal configuration files for macOS.

## Contents

- **git/** - Git configuration with separate profiles for personal and work
- **docker/** - Docker CLI configuration for Colima
- **wezterm.lua** - WezTerm terminal emulator configuration
- **nvim/** - Neovim configuration with lazy.nvim plugin manager
- **.editorconfig** - Editor configuration for consistent coding style

## Installation

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

Uses [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager. Plugins will be installed automatically on first launch.

#### First Launch Setup

1. **Start Neovim** - Plugins and LSP servers install automatically
   ```bash
   nvim
   ```

2. **Install TreeSitter parsers**
   ```vim
   :TSInstall javascript typescript tsx html css json lua bash php
   ```

3. **Set up Copilot** (optional, if using GitHub Copilot)
   ```vim
   :Copilot setup
   ```

4. **Verify installations**
   ```vim
   :Mason          " Check LSP servers & formatters
   :checkhealth    " Run health check
   ```

5. **Restart Neovim** - Everything should work without installation messages

#### Neovim Keybindings

Leader key: `Space`

**File Explorer**
- `<leader>e` - Toggle Neo-tree file explorer

**Telescope (Fuzzy Finder)**
- `<leader>ff` - Find files
- `<leader>fg` - Live grep (search in files)
- `<leader>fb` - Open buffers
- `<leader>fh` - Help tags
- `<leader>fc` - Commands palette
- `<leader>fk` - Show keymaps
- `<leader>gs` - Git status

**LSP (Language Server)**
- `K` - Hover documentation
- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementation
- `gr` - List references
- `<leader>D` - Go to type definition
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code actions
- `<leader>f` - Format buffer

**Diagnostics**
- `<leader>d` - Show line diagnostics
- `<leader>q` - Open diagnostics list
- `[d` - Previous diagnostic
- `]d` - Next diagnostic

**Git (Gitsigns)**
- `]c` - Next hunk
- `[c` - Previous hunk
- `<leader>hs` - Stage hunk (works in visual mode)
- `<leader>hr` - Reset hunk (works in visual mode)
- `<leader>hS` - Stage buffer
- `<leader>hR` - Reset buffer
- `<leader>hu` - Undo stage hunk
- `<leader>hp` - Preview hunk
- `<leader>hb` - Show blame for line
- `<leader>hd` - Show diff for file

**Copilot (Insert mode)**
- `<C-y>` - Accept suggestion
- `<C-j>` - Next suggestion
- `<C-k>` - Previous suggestion
- `<C-\>` - Dismiss suggestion

**Completion (Insert mode)**
- `<Tab>` - Next completion item / Expand snippet
- `<S-Tab>` - Previous completion item / Jump back in snippet
- `<CR>` - Confirm completion
- `<C-Space>` - Trigger completion
- `<C-e>` - Abort completion
- `<C-b>` - Scroll docs up
- `<C-f>` - Scroll docs down

**Commenting**
- `gcc` - Toggle line comment
- `gbc` - Toggle block comment
- `gc` - Toggle comment (visual mode)
- `gb` - Toggle block comment (visual mode)

### Docker

```bash
make docker-config-install
```

Copies `docker/config.json` to `~/.docker/config.json`. Configured for [Colima](https://github.com/abiosoft/colima) with Homebrew CLI plugins.

## License

MIT
