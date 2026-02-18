# Neovim Configuration

Modern Neovim 0.11+ configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager.

## Prerequisites

- `tree-sitter` CLI - required for compiling TreeSitter parsers (included in Brewfile)

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
   :TSInstall javascript typescript tsx html css json lua bash php svelte pug
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

## Structure

```
nvim/
├── init.lua              # Entry point
├── lazy-lock.json        # Plugin lockfile (pinned versions)
├── README.md             # This file
└── lua/
    ├── command.lua       # Custom commands
    ├── plugin.lua        # Lazy.nvim bootstrap
    ├── core/
    │   ├── filetypes.lua # Filetype overrides (.jade → pug)
    │   ├── options.lua   # Editor settings (leader, options)
    │   └── keymaps.lua   # Global keybindings
    ├── plugins/          # One file per plugin (auto-loaded)
    │   ├── lsp.lua       # LSP with Mason auto-install
    │   ├── conform.lua   # Format-on-save
    │   ├── cmp.lua       # Completion
    │   ├── telescope.lua # Fuzzy finder
    │   ├── gitsigns.lua  # Git integration
    │   ├── lualine.lua   # Statusline with breadcrumbs
    │   ├── yanky.lua     # Clipboard history with yank ring
    │   ├── copilot-chat/ # Copilot + commit workflow
    │   │   ├── init.lua        # Plugin spec
    │   │   ├── commands.lua    # GitCommit command
    │   │   ├── commit-window.lua # Commit preview UI
    │   │   └── utils.lua       # Git helpers
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
| `<C-y>` | Accept suggestion |
| `<C-j>` | Next suggestion |
| `<C-k>` | Previous suggestion |
| `<C-\>` | Dismiss suggestion |

### Completion (Insert mode)

| Key | Action |
|-----|--------|
| `<Tab>` | Next completion item / Expand snippet |
| `<S-Tab>` | Previous completion item / Jump back in snippet |
| `<CR>` | Confirm completion |
| `<C-Space>` | Trigger completion |
| `<C-e>` | Abort completion |
| `<C-b>` | Scroll docs up |
| `<C-f>` | Scroll docs down |

### Commenting

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gbc` | Toggle block comment |
| `gc` | Toggle comment (visual mode) |
| `gb` | Toggle block comment (visual mode) |

### Clipboard History (Yanky)

| Key | Action |
|-----|--------|
| `y` | Yank (tracked in history) |
| `p` | Put after |
| `P` | Put before |
| `]p` | Cycle to older yank after pasting |
| `[p` | Cycle to newer yank after pasting |
| `<leader>fy` | Browse full yank history in Telescope |

### Line Movement

| Key | Action |
|-----|--------|
| `<A-j>` | Move line/selection down |
| `<A-k>` | Move line/selection up |

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
- JS/TS/Svelte/Pug: Ensure `prettier` installed via Mason (Svelte and Pug need `prettier-plugin-svelte` / `@prettier/plugin-pug` in the project)
- Check `:ConformInfo`

**TreeSitter parsers not compiling:**
- Ensure `tree-sitter` CLI is installed: `brew install tree-sitter`
- Run `:TSUpdate` to update parsers
- Check `:checkhealth nvim-treesitter`
