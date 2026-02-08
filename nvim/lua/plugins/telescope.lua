return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-fzf-native.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    require('telescope').setup({
      defaults = {
        layout_config = {
          width = 0.9,
          height = 0.8,
        },
        file_ignore_patterns = { 'node_modules/', '.git/' },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        git_status = {
          git_icons = {
            added = '✚',
            changed = '✹',
            copied = '⧉',
            deleted = '✖',
            renamed = '➜',
            staged = '✓',
            unstaged = '✗',
            unmerged = '═',
            untracked = '◌',
          },
        },
        search_history = {
          theme = 'dropdown',
          previewer = false,
        },
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
