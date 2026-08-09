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

-- Options (server-appropriate).
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

-- Clipboard over SSH via OSC 52: `y` reaches the LOCAL clipboard (wezterm supports
-- OSC52 copy). Paste reads nvim's own register (no terminal round-trip — OSC52 paste
-- is usually blocked by terminals and would otherwise stall). Guarded for nvim < 0.10.
local ok_osc, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
if ok_osc then
  local function reg_paste() return vim.fn.getreg('"', 1, true) end
  vim.g.clipboard = {
    name = 'osc52-ssh',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = reg_paste, ['*'] = reg_paste },
  }
  vim.opt.clipboard = 'unnamedplus'
end

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
  -- grep_live() throws without rg/git, and git-grep only works inside a repo
  -- (fails in ~ or /tmp). So: rg => live grep (works anywhere); otherwise force
  -- the pure-Lua fallback grep, which is cwd/repo-independent.
  if vim.fn.executable('rg') == 1 then
    map('n', '<leader>fg', '<cmd>Pick grep_live<cr>', { desc = 'Live grep' })
  else
    map('n', '<leader>fg', function() require('mini.pick').builtin.grep({ tool = 'fallback' }) end,
      { desc = 'Grep (Lua fallback)' })
    vim.notify('ssh-remote nvim: no rg — live grep disabled, using slow Lua grep', vim.log.levels.WARN)
  end
end
