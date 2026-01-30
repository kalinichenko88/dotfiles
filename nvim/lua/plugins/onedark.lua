return {
  'navarasu/onedark.nvim',
  lazy = false,
  priority = 1000,
  config = function()
    local current_style = nil

    local function set_theme_by_system()
      local handle = io.popen('defaults read -g AppleInterfaceStyle 2>/dev/null')
      if not handle then
        vim.notify('Failed to read macOS system theme', vim.log.levels.ERROR)
        return
      end

      local result = handle:read('*a')
      handle:close()

      if not result then
        vim.notify('Failed to read system theme result', vim.log.levels.ERROR)
        return
      end

      local ok, onedark = pcall(require, 'onedark')
      if not ok then
        vim.notify('onedark not available', vim.log.levels.WARN)
        return
      end

      local new_style = result:match('Dark') and 'cool' or 'light'

      if current_style ~= new_style then
        onedark.setup({ style = new_style, transparent = true })
        onedark.load()
        current_style = new_style
      end
    end

    vim.api.nvim_create_autocmd('FocusGained', {
      callback = set_theme_by_system,
    })

    vim.api.nvim_create_autocmd('VimEnter', {
      callback = set_theme_by_system,
    })
  end,
}
