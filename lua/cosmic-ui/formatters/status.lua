local normalize = require('cosmic-ui.formatters.normalize')
local lsp_backend = require('cosmic-ui.formatters.backends.lsp')
local conform_backend = require('cosmic-ui.formatters.backends.conform')

local M = {}

local function resolve_fallback_reason(context, client)
  if not context.available then
    return 'conform unavailable'
  elseif not context.conform_enabled then
    return 'conform backend disabled'
  elseif not context.lsp_enabled then
    return 'lsp backend disabled'
  elseif context.mode == 'never' then
    return 'mode never'
  elseif not context.uses_lsp then
    if context.mode == 'fallback' then
      return 'formatters available'
    elseif context.mode == 'last' then
      return 'no conform formatters'
    end
    return 'mode inactive'
  elseif client then
    if not client.available then
      return 'lsp client unavailable'
    elseif not client.enabled then
      return 'lsp client disabled'
    end
    return 'eligible'
  end

  return nil
end

M.get = function(opts)
  opts = opts or {}

  local scope = normalize.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = normalize.resolve_bufnr(opts.bufnr)
  if not bufnr then
    return
  end

  local conform_data = conform_backend.get_conform_items(bufnr, scope)
  local lsp_clients, enabled_ids = lsp_backend.get_lsp_items(bufnr, scope)
  local lsp_state, lsp_enabled = lsp_backend.lsp_backend_state_from_items(scope, bufnr, enabled_ids)
  local conform_state, conform_enabled = conform_backend.conform_backend_state_from_items(scope, bufnr, conform_data)
  local requested_mode = nil
  if type(opts.conform) == 'table' then
    requested_mode = opts.conform.lsp_format
  end

  local mode_sources = conform_backend.resolve_conform_mode_sources(bufnr, requested_mode)
  local fallback_mode, fallback_source, configured_mode, configured_source =
    conform_backend.resolve_effective_conform_lsp_mode(mode_sources, lsp_enabled)
  local display_global_mode = mode_sources.global_mode or 'never'
  local display_specific_mode = mode_sources.specific_mode
  local display_specific_filetype = mode_sources.specific_filetype
  local fallback_available = conform_data.available
  local any_conform_formatters = false

  for _, formatter in ipairs(conform_data.items) do
    if formatter.effective_enabled then
      any_conform_formatters = true
      break
    end
  end

  local uses_lsp = conform_backend.conform_mode_uses_lsp(fallback_mode, any_conform_formatters)
  local eligible_clients = 0
  local fallback_context = {
    available = fallback_available,
    conform_enabled = conform_enabled,
    lsp_enabled = lsp_enabled,
    mode = fallback_mode,
    uses_lsp = uses_lsp,
  }
  local fallback_reason = resolve_fallback_reason(fallback_context)

  for _, client in ipairs(lsp_clients) do
    local reason = resolve_fallback_reason(fallback_context, client)
    local fallback = {
      eligible = false,
      reason = reason,
      mode = configured_mode,
      effective_mode = fallback_mode,
      source = fallback_source,
      configured_source = configured_source,
    }

    if reason == 'eligible' then
      fallback.eligible = true
      eligible_clients = eligible_clients + 1
    end

    client.conform_fallback = fallback
  end

  if not fallback_reason and eligible_clients == 0 then
    fallback_reason = 'no eligible lsp clients'
  end

  return {
    scope = scope,
    bufnr = bufnr,
    backends = {
      lsp = {
        enabled = lsp_enabled,
        available = lsp_state == 'ON',
        state = lsp_state,
      },
      conform = {
        enabled = conform_enabled,
        available = conform_data.available,
        state = conform_state,
      },
    },
    lsp_clients = lsp_clients,
    conform = {
      available = conform_data.available,
      reason = conform_data.reason,
      formatters = conform_data.items,
      fallback = {
        available = fallback_available,
        mode = configured_mode,
        effective_mode = fallback_mode,
        requested_mode = mode_sources.requested_mode,
        global_mode = mode_sources.global_mode,
        specific_mode = mode_sources.specific_mode,
        specific_filetype = mode_sources.specific_filetype,
        display_global_mode = display_global_mode,
        display_specific_mode = display_specific_mode,
        display_specific_filetype = display_specific_filetype,
        source = fallback_source,
        configured_source = configured_source,
        uses_lsp = uses_lsp,
        conform_enabled = conform_enabled,
        lsp_enabled = lsp_enabled,
        eligible_clients = eligible_clients,
        total_clients = #lsp_clients,
        reason = fallback_reason,
      },
    },
  }
end

return M
