return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-fzf-native.nvim",
  },
  config = function()
    require("telescope").setup({
      defaults = {
        file_ignore_patterns = { "node_modules/", ".git/" },
      },
    })
    pcall(require("telescope").load_extension, "fzf")
    pcall(require("telescope").load_extension, "egrepify")
  end,
}
