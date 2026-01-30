vim.api.nvim_create_user_command('CopyRelPath', function()
  local path = vim.fn.expand('%')
  if path == '' then
    vim.notify('No file name', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = 'Copy relative path of current file to clipboard' })

vim.api.nvim_create_user_command('CopyFileName', function()
  local filename = vim.fn.expand('%:t')
  if filename == '' then
    vim.notify('No file name', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', filename)
  vim.notify('Copied: ' .. filename)
end, { desc = 'Copy file name of current file to clipboard' })

vim.api.nvim_create_user_command('CopyGitBranch', function()
  local branch = vim.fn.systemlist('git branch --show-current')[1]

  if not branch or branch == '' then
    vim.notify('Not in a git repository', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', branch)
  vim.notify('Copied branch: ' .. branch)
end, { desc = 'Copy current git branch to clipboard' })
