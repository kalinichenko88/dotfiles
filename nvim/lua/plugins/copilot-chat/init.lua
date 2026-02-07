return {
  'CopilotC-Nvim/CopilotChat.nvim',
  dependencies = {
    'github/copilot.vim',
    'nvim-lua/plenary.nvim',
  },
  build = 'make tiktoken',
  cmd = {
    'CopilotChat',
    'CopilotChatCommit',
    'CopilotChatCommitStaged',
    'GitCommit',
  },
  opts = {},
  config = function(_, opts)
    require('CopilotChat').setup(opts)
    require('plugins.copilot-chat.commands').setup()
  end,
  keys = {
    { '<leader>cc', '<cmd>CopilotChat<cr>', desc = 'Copilot Chat' },
    { '<leader>cm', '<cmd>GitCommit<cr>', desc = 'Generate commit message' },
  },
}
