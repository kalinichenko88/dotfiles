local function get_commit_rules()
  local file = io.open(vim.fn.getcwd() .. '/.commit-rules', 'r')
  if file then
    local content = file:read('*all')
    file:close()
    return content
  end
  return [[
- Use conventional commits: type(scope): description
- Types: feat, fix, docs, style, refactor, test, chore
- Keep subject under 72 characters
- Use imperative mood
]]
end

local function show_commit_window(staged_files, message)
  local lines = { '  Staged Files:' }
  for file in staged_files:gmatch('[^\n]+') do
    table.insert(lines, '    ' .. file)
  end
  table.insert(lines, '')
  table.insert(lines, '  Commit Message:')
  table.insert(lines, '    ' .. message)
  table.insert(lines, '')
  table.insert(lines, '  ─────────────────────────────────────')
  table.insert(lines, '  <CR> Commit    <e> Edit    <q> Cancel')

  local width = 60
  for _, line in ipairs(lines) do
    if #line + 4 > width then
      width = #line + 4
    end
  end
  local height = #lines + 2

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Git Commit ',
    title_pos = 'center',
  })

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function do_commit()
    close_window()
    local escaped_message = message:gsub("'", "'\\''")
    local result = vim.fn.system("git commit -m '" .. escaped_message .. "'")
    if vim.v.shell_error == 0 then
      vim.notify('Committed: ' .. message, vim.log.levels.INFO)
    else
      vim.notify('Commit failed: ' .. result, vim.log.levels.ERROR)
    end
  end

  local function edit_message()
    close_window()

    local edit_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { message })
    vim.bo[edit_buf].bufhidden = 'wipe'

    local edit_win = vim.api.nvim_open_win(edit_buf, true, {
      relative = 'editor',
      width = 60,
      height = 5,
      col = math.floor((vim.o.columns - 60) / 2),
      row = math.floor((vim.o.lines - 5) / 2),
      style = 'minimal',
      border = 'rounded',
      title = ' Edit Commit Message (Enter to commit, Esc to cancel) ',
      title_pos = 'center',
    })

    vim.cmd('startinsert!')

    vim.keymap.set('n', '<Esc>', function()
      vim.api.nvim_win_close(edit_win, true)
    end, { buffer = edit_buf })

    vim.keymap.set({ 'n', 'i' }, '<CR>', function()
      local new_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
      local new_message = table.concat(new_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      vim.api.nvim_win_close(edit_win, true)

      if new_message == '' then
        vim.notify('Empty commit message', vim.log.levels.WARN)
        return
      end

      local escaped = new_message:gsub("'", "'\\''")
      local result = vim.fn.system("git commit -m '" .. escaped .. "'")
      if vim.v.shell_error == 0 then
        vim.notify('Committed: ' .. new_message:match('^[^\n]+'), vim.log.levels.INFO)
      else
        vim.notify('Commit failed: ' .. result, vim.log.levels.ERROR)
      end
    end, { buffer = edit_buf })
  end

  vim.keymap.set('n', '<CR>', do_commit, { buffer = buf })
  vim.keymap.set('n', 'e', edit_message, { buffer = buf })
  vim.keymap.set('n', 'q', close_window, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close_window, { buffer = buf })
end

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

    vim.api.nvim_create_user_command('GitCommit', function()
      local staged_diff = vim.fn.system('git diff --cached')
      if staged_diff == '' or staged_diff:match('^%s*$') then
        vim.notify('No staged changes', vim.log.levels.WARN)
        return
      end

      local staged_files = vim.fn.system('git diff --cached --name-only')
      local rules = get_commit_rules()
      local prompt = 'Write a concise commit message for the following staged changes. '
        .. 'Return ONLY the commit message, no explanation or markdown formatting.\n\n'
        .. 'Rules:\n'
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
          msg = msg:gsub('^```.-\n', ''):gsub('\n```$', ''):gsub('^%s+', ''):gsub('%s+$', '')
          vim.schedule(function()
            show_commit_window(staged_files, msg)
          end)
        end,
      })
    end, {})
  end,
  keys = {
    { '<leader>cc', '<cmd>CopilotChat<cr>', desc = 'Copilot Chat' },
    { '<leader>cm', '<cmd>GitCommit<cr>', desc = 'Generate commit message' },
    { '<leader>ca', '<cmd>CopilotChatActions<cr>', mode = { 'n', 'v' }, desc = 'Copilot actions' },
  },
}
