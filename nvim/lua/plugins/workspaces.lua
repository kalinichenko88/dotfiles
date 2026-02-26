return {
  'natecraddock/workspaces.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('workspaces').setup({
      hooks = {
        open = { 'Neotree dir=.', 'Telescope find_files' },
      },
    })
    require('telescope').load_extension('workspaces')
    vim.keymap.set('n', '<leader>fw', '<cmd>Telescope workspaces<cr>', { desc = 'Workspaces' })
  end,
}
