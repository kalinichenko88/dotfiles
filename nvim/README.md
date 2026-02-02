# Neovim Configuration

Modern Neovim 0.11+ configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager.

## Installation

```bash
make nvim-config-install
```

Symlinks `nvim/` directory to `~/.config/nvim`.

Plugins will be installed automatically on first launch.

## First Launch Setup

1. **Start Neovim** - Plugins and LSP servers install automatically
   ```bash
   nvim
   ```

2. **Install TreeSitter parsers**
   ```vim
   :TSInstall javascript typescript tsx html css json lua bash php
   ```

3. **Install formatters via Mason**
   ```vim
   :MasonInstall stylua prettier eslint_d
   ```

4. **Set up Copilot** (optional, if using GitHub Copilot)
   ```vim
   :Copilot setup
   ```

5. **Verify installations**
   ```vim
   :Mason          " Check LSP servers & formatters
   :checkhealth    " Run health check
   ```

6. **Restart Neovim** - Everything should work without installation messages

## Structure

```
nvim/
├── init.lua              # Entry point
├── stylua.toml           # Lua formatter config
└── lua/
    ├── config.lua        # Editor settings (leader key, options)
    ├── plugin.lua        # Lazy.nvim bootstrap
    ├── mapping.lua       # Global keybindings
    ├── command.lua       # Custom commands
    ├── core/
    │   └── keymaps.lua   # Core keymaps
    ├── plugins/          # One file per plugin (auto-loaded)
    │   ├── lsp.lua       # LSP with Mason auto-install
    │   ├── conform.lua   # Format-on-save
    │   ├── cmp.lua       # Completion
    │   ├── telescope.lua # Fuzzy finder
    │   ├── gitsigns.lua  # Git integration
    │   ├── copilot-chat.lua # Copilot + commit workflow
    │   └── ...
    └── themes/           # Custom themes
```

## Keybindings

Leader key: `Space`

### File Explorer

| Key | Action |
|-----|--------|
| `<leader>e` | Toggle Neo-tree file explorer |

### Telescope (Fuzzy Finder)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep (search in files) |
| `<leader>fb` | Open buffers |
| `<leader>fh` | Help tags |
| `<leader>fc` | Commands palette |
| `<leader>fk` | Show keymaps |
| `<leader>gs` | Git status |

### LSP (Language Server)

| Key | Action |
|-----|--------|
| `K` | Hover documentation |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gi` | Go to implementation |
| `gr` | List references |
| `<leader>D` | Go to type definition |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code actions |
| `<leader>f` | Format buffer |

### Diagnostics

| Key | Action |
|-----|--------|
| `<leader>d` | Show line diagnostics |
| `<leader>q` | Open diagnostics list |
| `[d` | Previous diagnostic |
| `]d` | Next diagnostic |

### Git (Gitsigns)

| Key | Action |
|-----|--------|
| `]c` | Next hunk |
| `[c` | Previous hunk |
| `<leader>hs` | Stage hunk (works in visual mode) |
| `<leader>hr` | Reset hunk (works in visual mode) |
| `<leader>hS` | Stage buffer |
| `<leader>hR` | Reset buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Show blame for line |
| `<leader>hd` | Show diff for file |

### Git (Diffview)

| Key | Action |
|-----|--------|
| `<leader>gd` | Open diffview |
| `<leader>gh` | Current file history |
| `<leader>gH` | Full branch history |
| `<leader>gc` | Close diffview |

### Git Commit (Copilot-powered)

Stage files and generate commit messages with AI:

1. `<leader>gs` - Open git status picker
2. `<Tab>` - Toggle stage/unstage selected file
3. `<leader>cm` - Generate commit message with Copilot

**Commit confirmation window:**

| Key | Action |
|-----|--------|
| `<CR>` | Commit with generated message |
| `e` | Edit message before committing |
| `q` / `<Esc>` | Cancel |

**Edit window:**

| Key | Action |
|-----|--------|
| `<C-s>` | Save and commit |
| `<Esc>` | Cancel |

**Project-specific commit rules**: Create `.commit-rules` in your project root to customize the commit message format. Falls back to conventional commits if not present.

### Copilot (Insert mode)

| Key | Action |
|-----|--------|
| `Ctrl+y` | Accept suggestion |
| `Ctrl+j` | Next suggestion |
| `Ctrl+k` | Previous suggestion |
| `Ctrl+\` | Dismiss suggestion |

### Completion (Insert mode)

| Key | Action |
|-----|--------|
| `<Tab>` | Next completion item / Expand snippet |
| `<S-Tab>` | Previous completion item / Jump back in snippet |
| `<CR>` | Confirm completion |
| `Ctrl+Space` | Trigger completion |
| `Ctrl+e` | Abort completion |
| `Ctrl+b` | Scroll docs up |
| `Ctrl+f` | Scroll docs down |

### Commenting

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gbc` | Toggle block comment |
| `gc` | Toggle comment (visual mode) |
| `gb` | Toggle block comment (visual mode) |

### Buffer Navigation

| Key | Action |
|-----|--------|
| `]b` | Next buffer |
| `[b` | Previous buffer |
| `<Esc>` | Clear search highlight |
| `<leader>w` | Save file |

## Adding Plugins

1. Create `nvim/lua/plugins/<plugin-name>.lua`
2. Return a lazy.nvim plugin spec table
3. Restart Neovim - lazy.nvim auto-imports from `plugins/` directory

## Troubleshooting

**LSP not working:**
- Run `:Mason` to check if servers installed
- Check `:LspInfo` to see attached servers

**Formatting not working:**
- Lua: Ensure `stylua` installed via Mason
- JS/TS: Ensure `prettier` installed via Mason
- Check `:ConformInfo`

**TreeSitter errors:**
- Run `:TSUpdate` to update parsers
- Check `:checkhealth nvim-treesitter`
