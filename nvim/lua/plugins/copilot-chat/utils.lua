local M = {}

function M.get_commit_rules()
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

function M.get_branch_name()
  local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('%s+$', '')
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return branch
end

return M
