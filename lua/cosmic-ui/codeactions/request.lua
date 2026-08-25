local M = {}

local function code_action_diagnostics(client_id, bufnr, lnum)
  local diagnostics = {}
  local client = vim.lsp.get_client_by_id(client_id)
  local capabilities = client and client.server_capabilities or {}
  local diagnostic_provider = capabilities.diagnosticProvider
  local pull_id = type(diagnostic_provider) == 'table' and diagnostic_provider.identifier or nil
  local ns_push = vim.lsp.diagnostic.get_namespace(client_id)
  local ns_pull
  -- 0.11 uses a pull boolean, 0.12.0 uses a provider ID, and 0.12.2 splits those into two arguments.
  if vim.fn.has('nvim-0.12.2') == 1 then
    ns_pull = vim.lsp.diagnostic.get_namespace(client_id, true, pull_id)
  elseif vim.fn.has('nvim-0.12') == 1 then
    ns_pull = vim.lsp.diagnostic.get_namespace(client_id, pull_id or 'nil')
  else
    ns_pull = vim.lsp.diagnostic.get_namespace(client_id, true)
  end

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
      on_complete(request_state)
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

  local completed = {}
  local function normalize_error(err)
    if type(err) == 'table' then
      return err
    end

    return {
      message = tostring(err or 'textDocument/codeAction request failed to start'),
    }
  end

  local function complete_request(client, err, result)
    if completed[client.id] then
      return
    end

    completed[client.id] = true
    results_lsp[client.id] = {
      error = err,
      result = result,
      client = client,
      bufnr = bufnr,
    }

    request_state.completed_clients = request_state.completed_clients + 1
    pending = pending - 1
    if pending > 0 then
      return
    end

    if on_complete then
      request_state.status = 'ready'
      on_complete(request_state)
    end
  end

  local function on_result(client)
    return function(err, result)
      complete_request(client, err, result)
    end
  end

  for _, prepared in ipairs(prepared_requests) do
    local ok, started = pcall(function()
      return prepared.client:request('textDocument/codeAction', prepared.params, on_result(prepared.client), bufnr)
    end)

    if not ok then
      complete_request(prepared.client, normalize_error(started), nil)
    elseif started == false then
      complete_request(prepared.client, normalize_error(), nil)
    end
  end
end

return M
