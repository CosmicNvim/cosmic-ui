local state = require('cosmic-ui.formatters.state')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

local function supports_lsp_formatting(client)
  if type(client.supports_method) == 'function' and client:supports_method('textDocument/formatting') then
    return true
  end

  local capabilities = client.server_capabilities or {}
  return capabilities.documentFormattingProvider == true
end

local function get_lsp_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  table.sort(clients, function(a, b)
    return a.name < b.name
  end)
  return clients
end

local function lsp_client_reason(client)
  if supports_lsp_formatting(client) then
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
    local reason = lsp_client_reason(client)
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

M.lsp_backend_state = function(scope, bufnr)
  local backend_enabled = state.get_effective_backend_state('lsp', scope, bufnr)
  if not backend_enabled then
    return 'OFF', backend_enabled
  end

  local _, enabled_ids = M.get_lsp_items(bufnr, scope)
  if next(enabled_ids) == nil then
    return 'UNAVAILABLE', backend_enabled
  end

  return 'ON', backend_enabled
end

M.run_lsp = function(opts)
  local bufnr = opts.bufnr
  local scope = opts.scope
  local async = opts.async
  local lsp_opts = opts.lsp_opts or {}
  local warn_once = opts.warn_once

  local client_items, enabled_ids = M.get_lsp_items(bufnr, scope)
  if next(enabled_ids) == nil then
    if #client_items == 0 then
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
  local format_opts = merged({
    bufnr = bufnr,
    async = async,
    filter = function(client)
      if not enabled_ids[client.id] then
        return false
      end
      if user_filter then
        return user_filter(client)
      end
      return true
    end,
  }, user_opts)

  local ok, err = pcall(vim.lsp.buf.format, format_opts)
  if not ok then
    logger:error(('LSP format failed: %s'):format(err))
    return false
  end

  return true
end

return M
