local constants = require('cosmic-ui.formatters.constants')

local M = {}

local state = {
  global = {
    backends = vim.deepcopy(constants.default_backend_state),
    items = {
      lsp = {},
      conform = {},
    },
  },
  buffers = {},
}

local function has_entries(tbl)
  return type(tbl) == 'table' and next(tbl) ~= nil
end

local function compact_buffer_state(bufnr)
  local buf_state = state.buffers[bufnr]
  if not buf_state then
    return
  end

  local has_backend = has_entries(buf_state.backends)
  local lsp_items = buf_state.items and buf_state.items.lsp or nil
  local conform_items = buf_state.items and buf_state.items.conform or nil
  local has_item = has_entries(lsp_items) or has_entries(conform_items)

  if not has_backend and not has_item then
    state.buffers[bufnr] = nil
  end
end

local function get_buffer_state(bufnr, create)
  local buf_state = state.buffers[bufnr]
  if buf_state then
    return buf_state
  end

  if not create then
    return nil
  end

  buf_state = {
    backends = {},
    items = {
      lsp = {},
      conform = {},
    },
  }
  state.buffers[bufnr] = buf_state
  return buf_state
end

local function get_scope_item_map(scope, bufnr, source, create)
  if scope == 'global' then
    return state.global.items[source]
  end

  local buf_state = get_buffer_state(bufnr, create)
  if not buf_state then
    return nil
  end

  if not buf_state.items[source] then
    if not create then
      return nil
    end

    buf_state.items[source] = {}
  end

  return buf_state.items[source]
end

M.get_effective_backend_state = function(backend, scope, bufnr)
  if scope == 'global' then
    return state.global.backends[backend]
  end

  local buf_state = get_buffer_state(bufnr, false)
  if buf_state and buf_state.backends[backend] ~= nil then
    return buf_state.backends[backend]
  end

  return state.global.backends[backend]
end

M.set_backend_state = function(backend, scope, bufnr, enabled)
  if scope == 'global' then
    state.global.backends[backend] = enabled
    return
  end

  local buf_state = get_buffer_state(bufnr, true)
  buf_state.backends[backend] = enabled
  compact_buffer_state(bufnr)
end

M.clear_backend_state = function(backend, scope, bufnr)
  if scope == 'global' then
    state.global.backends[backend] = constants.default_backend_state[backend]
    return
  end

  local buf_state = get_buffer_state(bufnr, false)
  if not buf_state then
    return
  end

  buf_state.backends[backend] = nil
  compact_buffer_state(bufnr)
end

M.get_effective_item_state = function(source, name, scope, bufnr)
  if scope == 'buffer' then
    local local_map = get_scope_item_map('buffer', bufnr, source, false)
    if local_map and local_map[name] ~= nil then
      return local_map[name]
    end
  end

  local global_map = state.global.items[source]
  if global_map[name] ~= nil then
    return global_map[name]
  end

  return true
end

M.set_item_state = function(source, name, scope, bufnr, enabled)
  local item_map = get_scope_item_map(scope, bufnr, source, true)
  item_map[name] = enabled
  if scope == 'buffer' then
    compact_buffer_state(bufnr)
  end
end

M.clear_item_state = function(source, name, scope, bufnr)
  local item_map = get_scope_item_map(scope, bufnr, source, false)
  if not item_map then
    return
  end

  item_map[name] = nil
  if scope == 'buffer' then
    compact_buffer_state(bufnr)
  end
end

M.clear_source_items = function(source, scope, bufnr)
  if scope == 'global' then
    state.global.items[source] = {}
    return
  end

  local buf_state = get_buffer_state(bufnr, false)
  if not buf_state then
    return
  end

  buf_state.items[source] = {}
  compact_buffer_state(bufnr)
end

M.current_buffer_has_backend_override = function(backends, bufnr)
  local buf_state = get_buffer_state(bufnr, false)
  if not buf_state then
    return false
  end

  for _, backend in ipairs(backends) do
    if buf_state.backends[backend] ~= nil then
      return true
    end
  end

  return false
end

return M
