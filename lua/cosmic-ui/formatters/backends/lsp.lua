local state = require('cosmic-ui.formatters.state')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

local function supports_lsp_method(client, method, bufnr)
  if type(client.supports_method) == 'function' then
    local supported = client:supports_method(method, bufnr)
    if supported ~= nil then
      return supported
    end
  end

  local capabilities = client.server_capabilities or {}
  if method == 'textDocument/formatting' then
    local provider = capabilities.documentFormattingProvider
    return provider == true or type(provider) == 'table'
  end

  local range_provider = capabilities.documentRangeFormattingProvider
  if method == 'textDocument/rangeFormatting' then
    return range_provider == true or type(range_provider) == 'table'
  end
  if method == 'textDocument/rangesFormatting' then
    return type(range_provider) == 'table' and range_provider.rangesSupport == true
  end

  return false
end

local function supports_lsp_formatting(client, bufnr)
  return supports_lsp_method(client, 'textDocument/formatting', bufnr)
end

local function get_lsp_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  table.sort(clients, function(a, b)
    return a.name < b.name
  end)
  return clients
end

local function lsp_client_reason(client, bufnr)
  if supports_lsp_formatting(client, bufnr) then
    return nil
  end

  local capabilities = client.server_capabilities or {}
  if capabilities.documentFormattingProvider == false or capabilities.documentRangeFormattingProvider == false then
    return 'disabled by config'
  end

  return 'unsupported'
end

M.get_lsp_items = function(bufnr, scope)
  local backend_enabled = state.get_effective_backend_state('lsp', scope, bufnr)
  local items = {}
  local enabled_ids = {}

  for _, client in ipairs(get_lsp_clients(bufnr)) do
    local reason = lsp_client_reason(client, bufnr)
    local available = reason == nil
    local item_enabled = state.get_effective_item_state('lsp', client.name, scope, bufnr)
    local effective_enabled = backend_enabled and item_enabled and available

    table.insert(items, {
      id = client.id,
      name = client.name,
      available = available,
      reason = reason,
      enabled = item_enabled,
      effective_enabled = effective_enabled,
    })

    if effective_enabled then
      enabled_ids[client.id] = true
    end
  end

  return items, enabled_ids
end

M.lsp_backend_state_from_items = function(scope, bufnr, enabled_ids)
  local backend_enabled = state.get_effective_backend_state('lsp', scope, bufnr)
  if not backend_enabled then
    return 'OFF', backend_enabled
  end

  if next(enabled_ids or {}) == nil then
    return 'UNAVAILABLE', backend_enabled
  end

  return 'ON', backend_enabled
end

M.lsp_backend_state = function(scope, bufnr)
  local _, enabled_ids = M.get_lsp_items(bufnr, scope)
  return M.lsp_backend_state_from_items(scope, bufnr, enabled_ids)
end

local function range_from_selection(bufnr, mode)
  local start = vim.fn.getpos('v')
  local finish = vim.fn.getpos('.')
  local start_row, start_col = start[2], start[3]
  local end_row, end_col = finish[2], finish[3]

  if start_row == end_row and end_col < start_col then
    start_col, end_col = end_col, start_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == 'V' then
    start_col = 1
    local line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)[1]
    end_col = #line
  end

  return {
    start = { start_row, start_col - 1 },
    ['end'] = { end_row, end_col - 1 },
  }
end

local function formatting_method_and_range(bufnr, requested_range)
  local range = requested_range
  local mode = vim.api.nvim_get_mode().mode
  if not range and (mode == 'v' or mode == 'V') then
    range = range_from_selection(bufnr, mode)
  end

  local has_multiple_ranges = range and #range > 0 and type(range[1]) == 'table'
  if has_multiple_ranges then
    return 'textDocument/rangesFormatting', range, true
  end
  if range then
    return 'textDocument/rangeFormatting', range, false
  end
  return 'textDocument/formatting', nil, false
end

local function make_formatting_params(bufnr, client, formatting_options, range, has_multiple_ranges)
  local ok, params = pcall(vim.api.nvim_buf_call, bufnr, function()
    return vim.lsp.util.make_formatting_params(formatting_options)
  end)
  if not ok then
    return nil, params
  end

  -- make_formatting_params() still derives the URI from buffer 0. Keep this
  -- explicit so every request remains tied to the target buffer.
  params.textDocument = { uri = vim.uri_from_bufnr(bufnr) }

  local function to_lsp_range(value)
    return vim.lsp.util.make_given_range_params(value.start, value['end'], bufnr, client.offset_encoding).range
  end

  if has_multiple_ranges then
    params.ranges = vim.tbl_map(to_lsp_range, range)
  elseif range then
    params.range = to_lsp_range(range)
  end

  return params
end

local function report_async_error(client, err)
  local message = type(err) == 'table' and err.message or err
  logger:error(('LSP format failed for %s: %s'):format(client.name, tostring(message or 'unknown error')))
end

local function handle_async_result(client, method, bufnr, err, result, ctx, handler_opts)
  if err then
    report_async_error(client, err)
  end

  local handler = (client.handlers or {})[method] or vim.lsp.handlers[method]
  if handler then
    local ok, handler_err = pcall(handler, err, result, ctx, handler_opts)
    if not ok then
      report_async_error(client, handler_err)
    end
  elseif not err and result then
    local ok, apply_err = pcall(vim.lsp.util.apply_text_edits, result, bufnr, client.offset_encoding)
    if not ok then
      report_async_error(client, apply_err)
    end
  end
end

local function run_async_format(bufnr, format_opts)
  local method, range, has_multiple_ranges = formatting_method_and_range(bufnr, format_opts.range)
  local clients = vim.lsp.get_clients({
    id = format_opts.id,
    bufnr = bufnr,
    name = format_opts.name,
    method = method,
  })

  if format_opts.filter then
    clients = vim.tbl_filter(format_opts.filter, clients)
  end
  table.sort(clients, function(a, b)
    return a.name < b.name
  end)

  if #clients == 0 then
    logger:warn('LSP formatting unavailable (no matching clients).')
    return false
  end

  local index = 0
  local function request_next()
    index = index + 1
    local client = clients[index]
    if not client then
      return
    end

    local params, params_err =
      make_formatting_params(bufnr, client, format_opts.formatting_options, range, has_multiple_ranges)
    if not params then
      report_async_error(client, params_err)
      return
    end

    local callback = function(err, result, ctx, handler_opts)
      handle_async_result(client, method, bufnr, err, result, ctx, handler_opts)
      request_next()
    end
    local ok, started = pcall(client.request, client, method, params, callback, bufnr)
    if not ok then
      report_async_error(client, started)
      request_next()
    elseif started == false then
      report_async_error(client, 'request failed to start')
      request_next()
    end
  end

  request_next()
  return true
end

M.run_lsp = function(opts)
  local bufnr = opts.bufnr
  local scope = opts.scope
  local async = opts.async
  local lsp_opts = opts.lsp_opts or {}
  local warn_once = opts.warn_once

  local method, resolved_range = formatting_method_and_range(bufnr, lsp_opts.range)
  local attached_clients = get_lsp_clients(bufnr)
  local backend_enabled = state.get_effective_backend_state('lsp', scope, bufnr)
  local enabled_ids = {}
  for _, client in ipairs(attached_clients) do
    local item_enabled = state.get_effective_item_state('lsp', client.name, scope, bufnr)
    if backend_enabled and item_enabled and supports_lsp_method(client, method, bufnr) then
      enabled_ids[client.id] = true
    end
  end

  if next(enabled_ids) == nil then
    if #attached_clients == 0 then
      logger:warn('LSP formatting unavailable (no clients attached).')
    elseif warn_once then
      warn_once('LSP formatting unavailable (all attached clients disabled or unsupported).')
    end
    return false
  end

  local user_filter = type(lsp_opts.filter) == 'function' and lsp_opts.filter or nil
  local user_opts = vim.deepcopy(lsp_opts)
  user_opts.filter = nil

  local merged = opts.merge_fn or function(left, right)
    return vim.tbl_deep_extend('force', left, right)
  end
  local format_opts = merged({}, user_opts)
  format_opts.bufnr = bufnr
  format_opts.async = async
  format_opts.range = resolved_range
  format_opts.filter = function(client)
    if not enabled_ids[client.id] then
      return false
    end
    if user_filter then
      return user_filter(client)
    end
    return true
  end

  if async then
    local ok, started = pcall(run_async_format, bufnr, format_opts)
    if not ok then
      logger:error(('LSP format failed: %s'):format(started))
      return false
    end
    return started
  end

  -- Neovim builds formatting params from the current buffer, even when
  -- `format_opts.bufnr` targets a different one. Run the call in the target
  -- buffer so its URI and indentation options are correct.
  local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.lsp.buf.format(format_opts)
  end)
  if not ok then
    logger:error(('LSP format failed: %s'):format(err))
    return false
  end

  return true
end

return M
