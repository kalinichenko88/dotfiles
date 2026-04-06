return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    -- Neovim 0.12 auto-starts treesitter for: lua, markdown, help, query
    -- Start it for all OTHER filetypes that have a parser installed
    local builtin_ts_fts = { lua = true, markdown = true, help = true, query = true }

    vim.api.nvim_create_autocmd('FileType', {
      pattern = '*',
      callback = function(args)
        if builtin_ts_fts[args.match] then
          return
        end
        pcall(vim.treesitter.start, args.buf)
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
        'svelte',
        'pug',
      },
      callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
