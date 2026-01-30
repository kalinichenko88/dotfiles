return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    -- Enable highlighting for all filetypes
    vim.api.nvim_create_autocmd('FileType', {
      pattern = '*',
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        pcall(vim.treesitter.start, buf)
      end,
    })

    -- Enable treesitter-based indentation
    vim.api.nvim_create_autocmd('FileType', {
      pattern = {
        'javascript',
        'typescript',
        'typescriptreact',
        'javascriptreact',
        'html',
        'css',
        'json',
        'lua',
        'bash',
        'php',
      },
      callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
