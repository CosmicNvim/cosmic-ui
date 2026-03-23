local states = require('cosmic-ui.ui.states')

local M = {}

local function sanitize_title(title)
  return title:gsub('\r\n', '\\r\\n'):gsub('\n', '\\n')
end

local function pluralize(count, singular, plural)
  if count == 1 then
    return ('1 %s'):format(singular)
  end

  return ('%d %s'):format(count, plural)
end

local function extract_request_state(results_lsp)
  if type(results_lsp) == 'table' and results_lsp.responses then
    return {
      status = results_lsp.status or 'ready',
      responses = results_lsp.responses,
      total_clients = results_lsp.total_clients or 0,
      completed_clients = results_lsp.completed_clients or 0,
    }
  end

  return {
    status = 'ready',
    responses = results_lsp or {},
    total_clients = 0,
    completed_clients = 0,
  }
end

local function push_row(rows, row, min_width)
  table.insert(rows, row)
  return math.max(min_width, vim.fn.strdisplaywidth(row.text or ''), 30)
end

M.build = function(results_lsp)
  local request_state = extract_request_state(results_lsp)
  local rows = {}
  local actions = {}
  local min_width = 30
  local error_count = 0

  if request_state.status == 'loading' then
    local loading_text = 'Loading code actions...'
    return {
      rows = {
        { kind = 'state', state = 'info', text = loading_text },
      },
      actions = actions,
      min_width = math.max(min_width, vim.fn.strdisplaywidth(loading_text)),
      has_partial_error = false,
      error_count = 0,
    }
  end

  local sorted_responses = {}
  for _, response in pairs(request_state.responses or {}) do
    if response.error then
      error_count = error_count + 1
    end

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
      min_width = push_row(rows, {
        kind = 'section',
        text = client.name,
      }, min_width)

      for _, result in ipairs(response.result) do
        local command_title = sanitize_title(result.title or '')
        local action = {
          kind = 'action',
          text = command_title,
          client = client,
          command = result,
        }

        min_width = math.max(min_width, vim.fn.strdisplaywidth(command_title), 30)
        table.insert(rows, action)
        table.insert(actions, action)
      end
    end
  end

  local has_partial_error = error_count > 0 and #actions > 0

  if #actions == 0 then
    if error_count > 0 then
      local error_text = pluralize(error_count, 'code action request failed', 'code action requests failed')
      rows = {
        { kind = 'state', state = 'error', text = error_text },
      }
      min_width = math.max(min_width, vim.fn.strdisplaywidth(error_text), 30)
    else
      local empty_row = states.empty('No code actions available')
      rows = { empty_row }
      min_width = math.max(min_width, vim.fn.strdisplaywidth(empty_row.text), 30)
    end
  elseif has_partial_error then
    local warning_text =
      pluralize(error_count, 'source failed to return code actions', 'sources failed to return code actions')
    table.insert(rows, 1, { kind = 'state', state = 'warn', text = warning_text })
    min_width = math.max(min_width, vim.fn.strdisplaywidth(warning_text), 30)
  end

  return {
    rows = rows,
    actions = actions,
    min_width = min_width,
    has_partial_error = has_partial_error,
    error_count = error_count,
  }
end

return M
