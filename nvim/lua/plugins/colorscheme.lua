return {
  {
    'sainnhe/everforest',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.everforest_background = 'hard'
      vim.g.everforest_transparent_background = 1
    end,
  },
  {
    'navarasu/onedark.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      local current_mode = nil

      local function set_theme_by_system()
        local handle = io.popen('defaults read -g AppleInterfaceStyle 2>/dev/null')
        if not handle then
          return
        end

        local result = handle:read('*a')
        handle:close()

        local is_dark = result and result:match('Dark')
        local new_mode = is_dark and 'dark' or 'light'

        if current_mode ~= new_mode then
          current_mode = new_mode

          if is_dark then
            vim.o.background = 'dark'
            vim.cmd.colorscheme('everforest')
          else
            require('onedark').setup({ style = 'light', transparent = true })
            require('onedark').load()
          end

          local ok, lualine = pcall(require, 'lualine')
          if ok then
            lualine.setup({ options = { theme = 'auto' } })
          end

          local ibl_ok, ibl = pcall(require, 'ibl')
          if ibl_ok then
            ibl.update()
          end

          local gs_ok, gitsigns = pcall(require, 'gitsigns')
          if gs_ok then
            gitsigns.refresh()
          end
        end
      end

      set_theme_by_system()

      vim.api.nvim_create_autocmd('FocusGained', {
        callback = set_theme_by_system,
      })
    end,
  },
}
