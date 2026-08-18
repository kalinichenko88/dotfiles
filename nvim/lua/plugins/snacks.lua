-- Inline images (png, svg, …) via the kitty graphics protocol, which WezTerm speaks.
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    image = {
      enabled = true,
      -- snacks leaves svg out and replaces this list instead of merging it, so
      -- its defaults have to be repeated.
      formats = vim.split('png jpg jpeg gif bmp webp tiff heic avif svg pdf mp4 mov avi mkv webm icns', ' '),
    },
  },
  init = function()
    -- WezTerm ignores the per-image delete snacks sends (a=d,d=i), so the old
    -- picture stays on screen and the next one lands on top of it. Wipe every
    -- placement when a buffer leaves its window instead.
    -- ponytail: this clears images in other windows too, and snacks only
    -- redraws a placement once its state changes, so a split showing an image
    -- stays blank until it scrolls or resizes. Drop the hook when WezTerm
    -- honours a=d,d=i.
    if vim.env.TERM_PROGRAM ~= 'WezTerm' then
      return
    end
    vim.api.nvim_create_autocmd('BufWinLeave', {
      callback = function()
        require('snacks.image').terminal.request({ a = 'd', d = 'a' })
      end,
    })
  end,
}
