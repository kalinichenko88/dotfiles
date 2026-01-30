return {
  "navarasu/onedark.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    local function set_theme_by_system()
      local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
      local result = handle:read("*a")
      handle:close()

      local ok, onedark = pcall(require, "onedark")
      if not ok then
        vim.notify("onedark not available", vim.log.levels.WARN)
        return
      end

      if result:match("Dark") then
        onedark.setup({ style = "cool", transparent = true })
      else
        onedark.setup({ style = "light", transparent = true })
      end
      onedark.load()
    end

    vim.api.nvim_create_autocmd("FocusGained", {
      callback = set_theme_by_system,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
      callback = set_theme_by_system,
    })
  end,
}
