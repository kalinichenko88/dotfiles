local utils = require('plugins.copilot-chat.utils')
local commit_window = require('plugins.copilot-chat.commit-window')

local M = {}

function M.setup()
  vim.api.nvim_create_user_command('GitCommit', function()
    local staged_diff = vim.fn.system('git diff --cached')
    if staged_diff == '' or staged_diff:match('^%s*$') then
      vim.notify('No staged changes', vim.log.levels.WARN)
      return
    end

    local staged_files = vim.fn.system('git diff --cached --name-only')
    local rules = utils.get_commit_rules()
    local branch = utils.get_branch_name()
    local prompt = 'Write a concise commit message for the following staged changes. '
      .. 'Return ONLY the commit message, no explanation or markdown formatting.\n\n'
      .. 'Current branch: '
      .. (branch or 'unknown')
      .. '\n\nRules:\n'
      .. rules
      .. '\n\nDiff:\n```diff\n'
      .. staged_diff
      .. '\n```'

    vim.notify('Generating commit message...', vim.log.levels.INFO)

    require('CopilotChat').ask(prompt, {
      headless = true,
      callback = function(response)
        local msg = response
        if type(response) == 'table' then
          msg = response.content or response.message or tostring(response)
        end
        -- Strip markdown code blocks (```lang\n...\n``` or ```\n...\n```)
        msg = msg:gsub('^%s*```[%w]*%s*\n', ''):gsub('\n%s*```%s*$', '')
        -- Strip inline code backticks
        msg = msg:gsub('^`', ''):gsub('`$', '')
        -- Trim whitespace
        msg = msg:gsub('^%s+', ''):gsub('%s+$', '')
        vim.schedule(function()
          commit_window.show(staged_files, msg)
        end)
      end,
    })
  end, {})
end

return M
