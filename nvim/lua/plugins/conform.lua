local function biome_or_prettier(bufnr)
  local has_biome = vim.fs.find({ 'biome.json', 'biome.jsonc' }, {
    upward = true,
    path = vim.api.nvim_buf_get_name(bufnr),
  })
  if #has_biome > 0 then
    return { 'biome' }
  end
  return { 'eslint_d', 'prettier' }
end

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  config = function()
    require('conform').setup({
      formatters_by_ft = {
        lua = { 'stylua' },
        javascript = biome_or_prettier,
        javascriptreact = biome_or_prettier,
        typescript = biome_or_prettier,
        typescriptreact = biome_or_prettier,
        json = biome_or_prettier,
        jsonc = biome_or_prettier,
        css = { 'prettier' },
        scss = { 'prettier' },
        html = { 'prettier' },
        svelte = { 'prettier' },
        astro = { 'prettier' },
        pug = { 'prettier' },
        mdx = { 'prettier' },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = 'fallback',
      },
    })
  end,
}
