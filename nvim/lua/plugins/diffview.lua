return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Diffview open' },
    { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'File history' },
    { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'Branch history' },
    { '<leader>gc', '<cmd>DiffviewClose<cr>', desc = 'Diffview close' },
  },
}
