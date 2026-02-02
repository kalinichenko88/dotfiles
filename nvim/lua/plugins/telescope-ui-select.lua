return {
  'nvim-telescope/telescope-ui-select.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('telescope').setup({
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown({
            width = 0.4,
            previewer = false,
          }),
        },
      },
    })
    require('telescope').load_extension('ui-select')
  end,
}
