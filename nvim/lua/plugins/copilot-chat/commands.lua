local utils = require('plugins.copilot-chat.utils')
local commit_window = require('plugins.copilot-chat.commit-window')

local M = {}

local function extract_message(response)
  if type(response) == 'string' then
    return response
  end

  if type(response) == 'table' then
    if type(response.content) == 'string' then
      return response.content
    end
    if type(response.message) == 'string' then
      return response.message
    end
    if type(response.text) == 'string' then
      return response.text
    end
  end

  return nil
end

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

    local max_diff_len = 15000
    local diff_section
    if #staged_diff > max_diff_len then
      local stat = vim.fn.system('git diff --cached --stat')
      diff_section = 'Diff stat (full diff too large):\n```\n'
        .. stat
        .. '```\n\nTruncated diff:\n```diff\n'
        .. staged_diff:sub(1, max_diff_len)
        .. '\n... (truncated)\n```'
    else
      diff_section = 'Diff:\n```diff\n' .. staged_diff .. '\n```'
    end

    local prompt = 'Write a concise commit message for the following staged changes. '
      .. 'Return ONLY the commit message, no explanation or markdown formatting.\n\n'
      .. 'Current branch: '
      .. (branch or 'unknown')
      .. '\n\nRules:\n'
      .. rules
      .. '\n\n'
      .. diff_section

    vim.notify('Generating commit message...', vim.log.levels.INFO)

    require('CopilotChat').ask(prompt, {
      headless = true,
      callback = function(response)
        local msg = extract_message(response)
        if not msg then
          vim.schedule(function()
            vim.notify('Failed to generate commit message: empty response', vim.log.levels.ERROR)
          end)
          return
        end
        -- Strip markdown code blocks (```lang\n...\n``` or ```\n...\n```)
        msg = msg:gsub('^%s*```[%w]*%s*\n', ''):gsub('\n%s*```%s*$', '')
        -- Strip inline code backticks
        msg = msg:gsub('^`', ''):gsub('`$', '')
        -- Trim whitespace
        msg = msg:gsub('^%s+', ''):gsub('%s+$', '')
        if msg == '' then
          vim.schedule(function()
            vim.notify('Generated commit message is empty', vim.log.levels.WARN)
          end)
          return
        end
        vim.schedule(function()
          commit_window.show(staged_files, msg)
        end)
      end,
    })
  end, {})
end

return M
