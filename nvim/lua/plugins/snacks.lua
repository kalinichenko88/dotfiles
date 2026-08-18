-- Inline images (png, svg, …) via the kitty graphics protocol, which WezTerm speaks.
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    image = {
      enabled = true,
      -- svg is missing from the snacks default list, and this replaces it
      -- wholesale, so the other formats have to be named too.
      formats = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'pdf' },
    },
  },
  init = function()
    -- WezTerm ignores the per-image delete snacks sends (a=d,d=i), so the old
    -- picture stays on screen and the next one lands on top of it. Wipe every
    -- placement when a buffer leaves its window instead.
    -- ponytail: d=a clears images in other windows too; they come back on their
    -- next update. Drop this whole hook once WezTerm honours a=d,d=i.
    vim.api.nvim_create_autocmd('BufWinLeave', {
      group = vim.api.nvim_create_augroup('snacks-image-wezterm-clear', { clear = true }),
      callback = function()
        local ok, image = pcall(require, 'snacks.image')
        if ok and image.terminal.env().name:find('wezterm') then
          image.terminal.request({ a = 'd', d = 'a' })
        end
      end,
    })
  end,
}
