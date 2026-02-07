return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-fzf-native.nvim',
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local actions = require('telescope.actions')

    require('telescope').setup({
      defaults = {
        layout_config = {
          width = 0.9,
          height = 0.8,
        },
        file_ignore_patterns = { 'node_modules/', '.git/' },
      },
      pickers = {
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
          attach_mappings = function(prompt_bufnr, map)
            local function toggle_stage_with_bufnr()
              actions.git_staging_toggle(prompt_bufnr)

              actions.close(prompt_bufnr)
              vim.schedule(function()
                vim.cmd('Telescope git_status')
              end)
            end

            map('i', '<Tab>', toggle_stage_with_bufnr)
            map('n', '<Tab>', toggle_stage_with_bufnr)
            return true
          end,
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
