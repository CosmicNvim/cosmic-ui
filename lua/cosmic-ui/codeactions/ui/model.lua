local M = {}

local function sanitize_title(title)
  return title:gsub('\r\n', '\\r\\n'):gsub('\n', '\\n')
end

M.build = function(results_lsp)
  local rows = {}
  local actions = {}
  local min_width = 0

  local sorted_responses = {}
  for _, response in pairs(results_lsp or {}) do
    if response.result and next(response.result) ~= nil then
      table.insert(sorted_responses, response)
    end
  end

  table.sort(sorted_responses, function(a, b)
    local a_client = a.client or {}
    local b_client = b.client or {}
    local a_name = a_client.name or ''
    local b_name = b_client.name or ''

    if a_name == b_name then
      return (a_client.id or 0) < (b_client.id or 0)
    end

    return a_name < b_name
  end)

  for _, response in ipairs(sorted_responses) do
    local client = response.client
    if client and client.name then
      table.insert(rows, {
        kind = 'separator',
        text = '(' .. client.name .. ')',
      })

      for _, result in ipairs(response.result) do
        local command_title = sanitize_title(result.title or '')
        local action = {
          kind = 'action',
          text = command_title,
          client = client,
          command = result,
        }

        min_width = math.max(min_width, #command_title, 30)
        table.insert(rows, action)
        table.insert(actions, action)
      end
    end
  end

  return {
    rows = rows,
    actions = actions,
    min_width = min_width,
  }
end

return M
