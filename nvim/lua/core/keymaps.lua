vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle file explorer' })

vim.keymap.set('n', '<Esc>', ':noh<CR>', { desc = 'Clear search highlight' })

vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope egrepify<cr>', { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fc', '<cmd>Telescope commands<cr>', { desc = 'Commands (palette)' })
vim.keymap.set('n', '<leader>fk', '<cmd>Telescope keymaps<cr>', { desc = 'Keymaps' })
vim.keymap.set('n', '<leader>gs', '<cmd>Telescope git_status<cr>', { desc = 'Git status' })

vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics list' })

vim.keymap.set('n', ']b', ':bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '[b', ':bprevious<CR>', { desc = 'Previous buffer' })
