return {
  'akioweh/lsp-document-highlight.nvim',
  event = 'LspAttach',
  config = function()
    vim.keymap.set('n', '[[', function()
      require('lsp-document-highlight').jump(-vim.v.count1, true)
    end, { desc = 'Previous Reference' })
    vim.keymap.set('n', ']]', function()
      require('lsp-document-highlight').jump(vim.v.count1, true)
    end, { desc = 'Next Reference' })
  end,
}
