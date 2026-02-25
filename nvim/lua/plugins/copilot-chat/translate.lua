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

local function sanitize_translation(text)
  text = text:gsub('\r\n', '\n')
  text = text:gsub('^%s*```[%w_-]*%s*\n', '')
  text = text:gsub('\n%s*```%s*$', '')
  return text
end

local function resolve_target_language(raw, callback)
  local arg = vim.trim(raw or '')
  if arg ~= '' then
    callback(arg)
    return
  end

  local default_language = vim.g.translate_default_target_language or 'Russian'
  vim.ui.input({ prompt = 'Translate to: ', default = default_language }, function(input)
    if not input then
      return
    end
    input = vim.trim(input)
    callback(input ~= '' and input or default_language)
  end)
end

local function ask_translation(text, target_language, callback)
  local prompt = ('Translate the text below to %s.\n'
    .. 'Rules:\n'
    .. '- Preserve meaning and tone.\n'
    .. '- Preserve Markdown formatting, code fences, inline code, links, headings, and lists.\n'
    .. '- Return only translated text without explanations.\n\n'
    .. 'Text:\n%s'):format(target_language, text)

  local ok, err = pcall(require('CopilotChat').ask, prompt, {
    headless = true,
    callback = function(response)
      local message = extract_message(response)
      if not message then
        vim.schedule(function()
          vim.notify('Translation failed: empty response', vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        callback(sanitize_translation(message))
      end)
    end,
  })

  if not ok then
    vim.notify('Copilot error: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.translate_line_range(line1, line2, target_language_arg)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = line1 - 1
  local end_line_exclusive = line2
  local selected_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line_exclusive, false)
  local text = table.concat(selected_lines, '\n')

  if text == '' or text:match('^%s*$') then
    vim.notify('Nothing to translate', vim.log.levels.WARN)
    return
  end

  resolve_target_language(target_language_arg, function(target_language)
    local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

    vim.notify(('Translating to %s...'):format(target_language), vim.log.levels.INFO)

    ask_translation(text, target_language, function(translated_text)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
        vim.notify('Buffer changed during translation. Re-run command.', vim.log.levels.WARN)
        return
      end

      local new_lines = vim.split(translated_text, '\n', { plain = true })
      vim.api.nvim_buf_set_lines(bufnr, start_line, end_line_exclusive, false, new_lines)
      vim.notify(('Translated to %s'):format(target_language), vim.log.levels.INFO)
    end)
  end)
end

function M.translate_buffer(target_language_arg)
  local total_lines = vim.api.nvim_buf_line_count(0)
  if total_lines == 0 then
    vim.notify('Nothing to translate', vim.log.levels.WARN)
    return
  end

  M.translate_line_range(1, total_lines, target_language_arg)
end

return M
