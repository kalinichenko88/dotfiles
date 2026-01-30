vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.relativenumber = false

vim.opt.signcolumn = 'yes'
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.mouse = 'a'
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.clipboard = 'unnamedplus'
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.undofile = true

vim.opt.ignorecase = true
vim.opt.smartcase = true


vim.diagnostic.config({ severity_sort = true })
