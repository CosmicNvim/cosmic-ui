local M = {}

local function code_action_diagnostics(client_id, bufnr, lnum)
  local diagnostics = {}
  local ns_push = vim.lsp.diagnostic.get_namespace(client_id, false)
  local ns_pull = vim.lsp.diagnostic.get_namespace(client_id, true)

  vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_pull, lnum = lnum }))
  vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_push, lnum = lnum }))

  local lsp_diagnostics = {}
  for _, diagnostic in ipairs(diagnostics) do
    local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
    if lsp_diagnostic then
      table.insert(lsp_diagnostics, lsp_diagnostic)
    end
  end

  return lsp_diagnostics
end

local function make_client_params(client, bufnr, opts, lnum)
  local params
  if opts.range and opts.range.start and opts.range['end'] then
    params = vim.lsp.util.make_given_range_params(opts.range.start, opts.range['end'], bufnr, client.offset_encoding)
  elseif opts.params then
    params = vim.deepcopy(opts.params)
  else
    params = vim.lsp.util.make_range_params(0, client.offset_encoding)
  end

  local context = vim.deepcopy(params.context or {})
  if not context.diagnostics then
    context.diagnostics = code_action_diagnostics(client.id, bufnr, lnum)
  end
  params.context = context

  return params
end

M.collect = function(opts)
  local bufnr = opts.bufnr
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local clients = opts.clients or {}
  local user_opts = opts.user_opts or {}
  local on_complete = opts.on_complete
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local pending = #clients
  local results_lsp = {}
  local prepared_requests = {}
  local request_state = {
    status = 'loading',
    responses = results_lsp,
    total_clients = pending,
    completed_clients = 0,
  }

  if pending == 0 then
    if on_complete then
      request_state.status = 'ready'
      on_complete(request_state, user_opts)
    end
    return
  end

  for _, client in ipairs(clients) do
    table.insert(prepared_requests, {
      client = client,
      params = make_client_params(client, bufnr, user_opts, lnum),
    })
  end

  if on_complete then
    on_complete(request_state, user_opts)
  end

  local function on_result(client)
    return function(err, result)
      results_lsp[client.id] = {
        error = err,
        result = result,
        client = client,
      }

      request_state.completed_clients = request_state.completed_clients + 1
      pending = pending - 1
      if pending > 0 then
        return
      end

      if on_complete then
        request_state.status = 'ready'
        on_complete(request_state, user_opts)
      end
    end
  end

  for _, prepared in ipairs(prepared_requests) do
    prepared.client:request('textDocument/codeAction', prepared.params, on_result(prepared.client), bufnr)
  end
end

return M
