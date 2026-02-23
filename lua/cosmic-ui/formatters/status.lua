local normalize = require('cosmic-ui.formatters.normalize')
local lsp_backend = require('cosmic-ui.formatters.backend_lsp')
local conform_backend = require('cosmic-ui.formatters.backend_conform')

local M = {}

M.get = function(opts)
  opts = opts or {}

  local scope = normalize.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = normalize.resolve_bufnr(opts.bufnr)

  local lsp_state, lsp_enabled = lsp_backend.lsp_backend_state(scope, bufnr)
  local conform_state, conform_enabled = conform_backend.conform_backend_state(scope, bufnr)
  local lsp_clients = lsp_backend.get_lsp_items(bufnr, scope)
  local conform_data = conform_backend.get_conform_items(bufnr, scope)
  local mode_sources = conform_backend.resolve_conform_mode_sources(bufnr, nil)
  local fallback_mode, fallback_source, configured_mode, configured_source =
    conform_backend.resolve_effective_conform_lsp_mode(mode_sources, lsp_enabled)
  local display_global_mode = mode_sources.global_mode or 'never'
  local display_specific_mode = mode_sources.specific_mode
  local display_specific_filetype = mode_sources.specific_filetype
  local fallback_reason = nil
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

  if not fallback_available then
    fallback_reason = 'conform unavailable'
  elseif not conform_enabled then
    fallback_reason = 'conform backend disabled'
  elseif not lsp_enabled then
    fallback_reason = 'lsp backend disabled'
  elseif fallback_mode == 'never' then
    fallback_reason = 'mode never'
  elseif not uses_lsp then
    if fallback_mode == 'fallback' then
      fallback_reason = 'formatters available'
    elseif fallback_mode == 'last' then
      fallback_reason = 'no conform formatters'
    else
      fallback_reason = 'mode inactive'
    end
  end

  for _, client in ipairs(lsp_clients) do
    local fallback = {
      eligible = false,
      reason = 'eligible',
      mode = configured_mode,
      effective_mode = fallback_mode,
      source = fallback_source,
      configured_source = configured_source,
    }

    if not fallback_available then
      fallback.reason = 'conform unavailable'
    elseif not conform_enabled then
      fallback.reason = 'conform backend disabled'
    elseif not lsp_enabled then
      fallback.reason = 'lsp backend disabled'
    elseif fallback_mode == 'never' then
      fallback.reason = 'mode never'
    elseif not uses_lsp then
      if fallback_mode == 'fallback' then
        fallback.reason = 'formatters available'
      elseif fallback_mode == 'last' then
        fallback.reason = 'no conform formatters'
      else
        fallback.reason = 'mode inactive'
      end
    elseif not client.available then
      fallback.reason = 'lsp client unavailable'
    elseif not client.enabled then
      fallback.reason = 'lsp client disabled'
    else
      fallback.eligible = true
      fallback.reason = 'eligible'
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
