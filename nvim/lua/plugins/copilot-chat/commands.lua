local utils = require('plugins.copilot-chat.utils')
local commit_window = require('plugins.copilot-chat.commit-window')
local translator = require('plugins.copilot-chat.translate')

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

    -- CopilotChat in headless mode swallows errors (only writes to its log file)
    -- and never invokes the callback on failure. To surface failures (expired
    -- subscription, auth issues, etc.) we poll the log file size and bail out
    -- as soon as a new ERROR line appears, plus a hard timeout as a backstop.
    local done = false
    local log_path = vim.fn.stdpath('state') .. '/CopilotChat.log'
    local initial_log_size = (vim.uv.fs_stat(log_path) or {}).size or 0
    local timer = vim.uv.new_timer()
    local poll_timer = vim.uv.new_timer()

    local function cleanup()
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if not poll_timer:is_closing() then
        poll_timer:stop()
        poll_timer:close()
      end
    end

    local function fail(msg)
      if done then
        return
      end
      done = true
      cleanup()
      vim.schedule(function()
        vim.notify(msg, vim.log.levels.ERROR)
      end)
    end

    -- Hard timeout backstop (in case CopilotChat hangs without logging).
    timer:start(
      60000,
      0,
      vim.schedule_wrap(function()
        fail('Commit message generation timed out after 60s. Check :CopilotChatLog.')
      end)
    )

    -- Poll the log for new ERROR entries to fail fast on auth/quota issues.
    poll_timer:start(
      300,
      300,
      vim.schedule_wrap(function()
        if done then
          return
        end
        local stat = vim.uv.fs_stat(log_path)
        if not stat or stat.size <= initial_log_size then
          return
        end
        local fd = vim.uv.fs_open(log_path, 'r', 438)
        if not fd then
          return
        end
        local chunk = vim.uv.fs_read(fd, stat.size - initial_log_size, initial_log_size) or ''
        vim.uv.fs_close(fd)
        local err_line = chunk:match('%[ERROR[^\n]+')
        if err_line then
          local detail = err_line:gsub('^%[ERROR[^%]]+%]%s*', ''):gsub('^[^:]+:%d+:%s*', '')
          fail('Copilot error: ' .. detail .. '\nFull log: :CopilotChatLog')
        end
      end)
    )

    local ok, err = pcall(require('CopilotChat').ask, prompt, {
      headless = true,
      callback = function(response)
        if done then
          return
        end
        done = true
        cleanup()
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
    if not ok then
      fail('Copilot error: ' .. tostring(err))
    end
  end, {})

  vim.api.nvim_create_user_command('Translate', function(args)
    translator.translate_line_range(args.line1, args.line2, args.args)
  end, {
    desc = 'Translate selected lines (or current line)',
    nargs = '*',
    range = true,
  })

  vim.api.nvim_create_user_command('TranslateBuffer', function(args)
    translator.translate_buffer(args.args)
  end, {
    desc = 'Translate current buffer',
    nargs = '*',
  })
end

return M
