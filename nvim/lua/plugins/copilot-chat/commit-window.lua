local M = {}

function M.show(staged_files, message)
  local lines = { '  Staged Files:' }
  for file in staged_files:gmatch('[^\n]+') do
    table.insert(lines, '    ' .. file)
  end
  table.insert(lines, '')
  table.insert(lines, '  Commit Message:')
  for msg_line in message:gmatch('[^\n]+') do
    table.insert(lines, '    ' .. msg_line)
  end
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
    vim.cmd('echo ""')
  end

  local function do_commit()
    close_window()
    vim.notify('Committing...', vim.log.levels.INFO)
    local result = vim.fn.system({ 'git', 'commit', '-m', message })
    if vim.v.shell_error == 0 then
      vim.notify('Committed: ' .. message:match('^[^\n]+'), vim.log.levels.INFO)
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
      title = ' Edit Commit Message (<C-s> commit, Esc cancel) ',
      title_pos = 'center',
    })

    vim.cmd('startinsert!')

    vim.keymap.set({ 'n', 'i' }, '<Esc>', function()
      vim.cmd('stopinsert')
      vim.api.nvim_win_close(edit_win, true)
      vim.cmd('echo ""')
    end, { buffer = edit_buf })

    vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
      local new_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
      local new_message = table.concat(new_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      vim.api.nvim_win_close(edit_win, true)

      if new_message == '' then
        vim.notify('Empty commit message', vim.log.levels.WARN)
        return
      end

      vim.notify('Committing...', vim.log.levels.INFO)
      local result = vim.fn.system({ 'git', 'commit', '-m', new_message })
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

return M
