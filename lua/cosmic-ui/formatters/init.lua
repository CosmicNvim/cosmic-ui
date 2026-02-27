local config = require('cosmic-ui.config')
local normalize = require('cosmic-ui.formatters.normalize')
local state = require('cosmic-ui.formatters.state')
local lsp_backend = require('cosmic-ui.formatters.backend_lsp')
local conform_backend = require('cosmic-ui.formatters.backend_conform')
local status = require('cosmic-ui.formatters.status')
local ui = require('cosmic-ui.formatters.ui')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

local function warn_once(msg)
  local global_opts = config.get() or {}
  local title = global_opts.notify_title or 'CosmicUI'
  vim.notify_once(msg, vim.log.levels.WARN, { title = title })
end

local function notify_global_override(backends)
  local bufnr = vim.api.nvim_get_current_buf()
  if state.current_buffer_has_backend_override(backends, bufnr) then
    logger:warn('Global formatter state changed, but this buffer has local formatter overrides.')
  end
end

local function backend_summary(scope, bufnr)
  local lsp_state = lsp_backend.lsp_backend_state(scope, bufnr)
  local conform_state = conform_backend.conform_backend_state(scope, bufnr)
  return ('Formatters [%s] lsp=%s conform=%s'):format(scope, lsp_state, conform_state)
end

local function mutate_backends(opts, mutator, action_name)
  local normalized = normalize.normalize_scope_backends_bufnr(opts)
  if not normalized then
    return
  end

  for _, backend in ipairs(normalized.backends) do
    mutator(backend, normalized.scope, normalized.bufnr)
  end

  if normalized.scope == 'global' then
    notify_global_override(normalized.backends)
  end

  logger:log(backend_summary(normalized.scope, normalized.bufnr), {
    title = ('Formatters: %s'):format(action_name),
  })
end

local function mutate_item(opts, mutator, action_name)
  local normalized = normalize.normalize_item_opts(opts)
  if not normalized then
    return
  end

  mutator(normalized)

  logger:log(
    ('Formatters [%s] %s:%s=%s'):format(
      normalized.scope,
      normalized.source,
      normalized.name,
      tostring(state.get_effective_item_state(normalized.source, normalized.name, normalized.scope, normalized.bufnr))
    ),
    {
      title = ('Formatters: %s'):format(action_name),
    }
  )
end

local function format_internal(opts, async)
  opts = opts or {}
  local scope = normalize.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = normalize.resolve_bufnr(opts.bufnr)
  if not bufnr then
    return
  end

  local requested = normalize.normalize_backends(opts.backend)
  if not requested then
    return
  end

  local requested_set = {}
  for _, backend in ipairs(requested) do
    requested_set[backend] = true
  end

  local conform_enabled = requested_set.conform and state.get_effective_backend_state('conform', scope, bufnr)
  local lsp_enabled = requested_set.lsp and state.get_effective_backend_state('lsp', scope, bufnr)
  if not conform_enabled and not lsp_enabled then
    logger:warn('No enabled formatters available for this scope.')
    return false
  end

  local conform_opts = vim.deepcopy(opts.conform or {})
  local lsp_opts = vim.deepcopy(opts.lsp or {})

  local conform = conform_backend.get_conform_module()
  if conform then
    if conform_enabled then
      return conform_backend.run_conform({
        conform = conform,
        bufnr = bufnr,
        scope = scope,
        async = async,
        conform_opts = conform_opts,
        lsp_enabled = lsp_enabled,
        warn_once = warn_once,
        merge_fn = utils.merge,
      })
    end

    if lsp_enabled then
      return lsp_backend.run_lsp({
        bufnr = bufnr,
        scope = scope,
        async = async,
        lsp_opts = lsp_opts,
        warn_once = warn_once,
        merge_fn = utils.merge,
      })
    end

    logger:warn('No enabled formatters available for this scope.')
    return false
  end

  if conform_enabled then
    if lsp_enabled then
      warn_once('Conform.nvim not available; using LSP formatting fallback.')
    else
      warn_once('Conform.nvim not available; skipping conform formatter.')
      return false
    end
  end

  if lsp_enabled then
    return lsp_backend.run_lsp({
      bufnr = bufnr,
      scope = scope,
      async = async,
      lsp_opts = lsp_opts,
      warn_once = warn_once,
      merge_fn = utils.merge,
    })
  end

  logger:warn('No enabled formatters available for this scope.')
  return false
end

M.open = function(opts)
  return ui.open(opts, {
    resolve_scope = normalize.resolve_scope,
    resolve_bufnr = normalize.resolve_bufnr,
    status_fn = M.status,
    reset_fn = M.reset,
    format_async_fn = M.format_async,
  })
end

M.toggle = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    local current = state.get_effective_backend_state(backend, scope, bufnr)
    state.set_backend_state(backend, scope, bufnr, not current)
  end, 'toggle')
end

M.enable = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    state.set_backend_state(backend, scope, bufnr, true)
  end, 'enable')
end

M.disable = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    state.set_backend_state(backend, scope, bufnr, false)
  end, 'disable')
end

M.toggle_item = function(opts)
  mutate_item(opts, function(item)
    local current = state.get_effective_item_state(item.source, item.name, item.scope, item.bufnr)
    state.set_item_state(item.source, item.name, item.scope, item.bufnr, not current)
  end, 'toggle_item')
end

M.enable_item = function(opts)
  mutate_item(opts, function(item)
    state.set_item_state(item.source, item.name, item.scope, item.bufnr, true)
  end, 'enable_item')
end

M.disable_item = function(opts)
  mutate_item(opts, function(item)
    state.set_item_state(item.source, item.name, item.scope, item.bufnr, false)
  end, 'disable_item')
end

M.is_item_enabled = function(opts)
  local normalized = normalize.normalize_item_opts(opts)
  if not normalized then
    return
  end

  return state.get_effective_item_state(normalized.source, normalized.name, normalized.scope, normalized.bufnr)
end

M.reset = function(opts)
  opts = opts or {}

  local scope = normalize.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = normalize.resolve_bufnr(opts.bufnr)
  if not bufnr then
    return
  end

  if opts.source ~= nil then
    local source = normalize.normalize_source(opts.source)
    if not source then
      return
    end

    if opts.name ~= nil then
      local name = normalize.normalize_name(opts.name)
      if not name then
        return
      end
      state.clear_item_state(source, name, scope, bufnr)
    else
      state.clear_source_items(source, scope, bufnr)
    end

    logger:log(('Formatters [%s] reset %s item overrides'):format(scope, source), {
      title = 'Formatters: reset',
    })
    return
  end

  local backends = normalize.normalize_backends(opts.backend)
  if not backends then
    return
  end

  for _, backend in ipairs(backends) do
    state.clear_backend_state(backend, scope, bufnr)
  end

  if opts.backend == nil then
    state.clear_source_items('lsp', scope, bufnr)
    state.clear_source_items('conform', scope, bufnr)
  end

  if scope == 'global' then
    notify_global_override(backends)
  end

  logger:log(backend_summary(scope, bufnr), {
    title = 'Formatters: reset',
  })
end

M.is_enabled = function(opts)
  opts = opts or {}

  local scope = normalize.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = normalize.resolve_bufnr(opts.bufnr)
  if not bufnr then
    return
  end

  if opts.backend ~= nil then
    local backends = normalize.normalize_backends(opts.backend)
    if not backends then
      return
    end

    if #backends == 1 then
      return state.get_effective_backend_state(backends[1], scope, bufnr)
    end
  end

  return {
    lsp = state.get_effective_backend_state('lsp', scope, bufnr),
    conform = state.get_effective_backend_state('conform', scope, bufnr),
  }
end

M.status = function(opts)
  return status.get(opts)
end

M.format = function(opts)
  return format_internal(opts, false)
end

M.format_async = function(opts)
  return format_internal(opts, true)
end

return M
