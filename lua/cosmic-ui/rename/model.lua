local M = {}

function M.normalize_submission(prompt, raw_line, current_name)
  local submitted = vim.startswith(raw_line, prompt) and raw_line:sub(#prompt + 1) or raw_line

  if submitted == '' then
    return { ok = false, reason = 'empty' }
  end

  if submitted == current_name then
    return { ok = false, reason = 'unchanged' }
  end

  return { ok = true, value = submitted }
end

return M
