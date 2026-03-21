local M = {}

function M.extract_value(prompt, raw_line)
  if vim.startswith(raw_line, prompt) then
    return raw_line:sub(#prompt + 1)
  end

  return raw_line
end

function M.normalize_submission(prompt, raw_line, current_name)
  local submitted = M.extract_value(prompt, raw_line)

  if submitted == '' then
    return { ok = false, reason = 'empty' }
  end

  if submitted == current_name then
    return { ok = false, reason = 'unchanged' }
  end

  return { ok = true, value = submitted }
end

return M
