return {
  'nvim-lualine/lualine.nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'SmiteshP/nvim-navic',
  },
  config = function()
    require('nvim-navic').setup({
      lsp = { auto_attach = true },
      highlight = true,
    })

    require('lualine').setup({
      options = {
        theme = 'auto',
        globalstatus = true,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diagnostics' },
        lualine_c = {
          { 'filename', path = 1 },
          {
            function()
              return require('nvim-navic').get_location()
            end,
            cond = function()
              return require('nvim-navic').is_available()
            end,
          },
        },
        lualine_x = { 'filetype' },
        lualine_y = {
          { 'progress', separator = ' ', padding = { left = 1, right = 0 } },
          { 'location', padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          function()
            return ' ' .. os.date('%H:%M')
          end,
        },
      },
    })
  end,
}
