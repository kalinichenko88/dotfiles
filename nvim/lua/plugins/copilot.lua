return {
  'github/copilot.vim',
  event = 'InsertEnter',
  config = function()
    vim.g.copilot_no_tab_map = true
    vim.keymap.set('i', '<C-y>', 'copilot#Accept("\\<CR>")', {
      expr = true,
      replace_keycodes = false,
      desc = 'Accept Copilot suggestion',
    })
    vim.keymap.set('i', '<C-j>', '<Plug>(copilot-next)', { desc = 'Next Copilot suggestion' })
    vim.keymap.set('i', '<C-k>', '<Plug>(copilot-previous)', { desc = 'Previous Copilot suggestion' })
    vim.keymap.set('i', '<C-\\>', '<Plug>(copilot-dismiss)', { desc = 'Dismiss Copilot suggestion' })
  end,
}
