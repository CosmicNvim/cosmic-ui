local M = {}

function M.empty(text)
  return { kind = "state", state = "empty", text = text }
end

return M
