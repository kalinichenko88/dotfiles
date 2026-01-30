return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-fzf-native.nvim',
  },
  config = function()
    require('telescope').setup({
      defaults = {
        file_ignore_patterns = { 'node_modules/', '.git/' },
      },
    })

    local ok, err = pcall(require('telescope').load_extension, 'fzf')
    if not ok then
      vim.notify('Failed to load fzf extension: ' .. err, vim.log.levels.WARN)
    end

    ok, err = pcall(require('telescope').load_extension, 'egrepify')
    if not ok then
      vim.notify('Failed to load egrepify extension: ' .. err, vim.log.levels.WARN)
    end
  end,
}
