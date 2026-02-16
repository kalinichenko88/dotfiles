return {
  'neovim/nvim-lspconfig',
  dependencies = {
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    'hrsh7th/cmp-nvim-lsp',
  },

  config = function()
    require('mason').setup()

    local servers = { 'ts_ls', 'eslint', 'html', 'cssls', 'jsonls', 'tailwindcss', 'emmet_ls', 'phpactor', 'lua_ls', 'svelte', 'astro' }
    local ensure = { 'prettier', 'eslint_d', 'stylua', 'pug-lsp' }
    vim.list_extend(ensure, servers)

    require('mason-tool-installer').setup({
      ensure_installed = ensure,
      run_on_start = true,
    })

    require('mason-lspconfig').setup({
      ensure_installed = servers,
      automatic_enable = false,
    })

    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    local function on_attach(client, bufnr)
      if client.name == 'ts_ls' or client.name == 'eslint' then
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end

      local nmap = function(keys, func, desc)
        vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
      end

      nmap('K', vim.lsp.buf.hover, 'Hover documentation')
      nmap('gd', vim.lsp.buf.definition, 'Go to definition')
      nmap('gD', vim.lsp.buf.declaration, 'Go to declaration')
      nmap('gi', vim.lsp.buf.implementation, 'Go to implementation')
      nmap('gr', vim.lsp.buf.references, 'List references')
      nmap('<leader>D', vim.lsp.buf.type_definition, 'Type definition')
      nmap('<leader>rn', vim.lsp.buf.rename, 'Rename')
      nmap('<leader>ca', vim.lsp.buf.code_action, 'Code action')
      nmap('<leader>f', function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end, 'Format buffer')

      nmap('[d', vim.diagnostic.goto_prev, 'Previous diagnostic')
      nmap(']d', vim.diagnostic.goto_next, 'Next diagnostic')
    end

    vim.lsp.config('*', {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config('lua_ls', {
      settings = {
        Lua = {
          runtime = { version = 'LuaJIT' },
          diagnostics = {
            globals = { 'vim' },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file('', true),
            checkThirdParty = false,
          },
          telemetry = { enable = false },
        },
      },
    })

    vim.lsp.config('eslint', {
      filetypes = {
        'javascript',
        'javascriptreact',
        'javascript.jsx',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
        'vue',
        'svelte',
        'astro',
        'html',
      },
      settings = {
        workingDirectories = { mode = 'auto' },
      },
    })

    vim.lsp.config('emmet_ls', {
      filetypes = {
        'html',
        'css',
        'scss',
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'svelte',
        'vue',
        'astro',
      },
    })

    vim.lsp.enable(servers)
    vim.lsp.enable('pug')
  end,
}
