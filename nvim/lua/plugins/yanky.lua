return {
  'gbprod/yanky.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('yanky').setup({})
    require('telescope').load_extension('yank_history')

    vim.keymap.set({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', { desc = 'Yank' })
    vim.keymap.set({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', { desc = 'Put after' })
    vim.keymap.set({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', { desc = 'Put before' })
    vim.keymap.set('n', ']p', '<Plug>(YankyCycleForward)', { desc = 'Cycle yank forward' })
    vim.keymap.set('n', '[p', '<Plug>(YankyCycleBackward)', { desc = 'Cycle yank backward' })

    vim.keymap.set('n', '<leader>fy', '<cmd>Telescope yank_history<cr>', { desc = 'Yank history' })
  end,
}
