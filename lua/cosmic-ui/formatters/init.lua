local config = require('cosmic-ui.config')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

local backend_order = { 'conform', 'lsp' }
local default_backend_state = {
  lsp = true,
  conform = true,
}

local state = {
  global = {
    backends = vim.deepcopy(default_backend_state),
    items = {
      lsp = {},
      conform = {},
    },
  },
  buffers = {},
  ui = nil,
  ui_ns = nil,
}

local status_icons = {
  enabled = '',
  disabled = '󰄱',
  unavailable = '',
}

local ui_padding = {
  x = 1,
  y = 0,
}

local highlight_links = {
  CosmicUiFmtTitle = 'Title',
  CosmicUiFmtHeader = 'Identifier',
  CosmicUiFmtSection = 'Type',
  CosmicUiFmtHintKey = 'Special',
  CosmicUiFmtHintText = 'Comment',
  CosmicUiFmtEnabled = 'String',
  CosmicUiFmtDisabled = 'Comment',
  CosmicUiFmtUnavailable = 'WarningMsg',
  CosmicUiFmtIcon = 'Function',
}

local function warn_once(msg)
  local global_opts = config.get() or {}
  local title = global_opts.notify_title or 'CosmicUI'
  vim.notify_once(msg, vim.log.levels.WARN, { title = title })
end

local function resolve_scope(scope)
  if scope == nil then
    return 'buffer'
  end

  if scope == 'buffer' or scope == 'global' then
    return scope
  end

  logger:warn(("Invalid formatter scope `%s`; expected `buffer` or `global`."):format(tostring(scope)))
  return nil
end

local function resolve_bufnr(bufnr)
  local resolved = bufnr or 0
  if resolved == 0 then
    resolved = vim.api.nvim_get_current_buf()
  end
  return resolved
end

local function normalize_backends(backend)
  if backend == nil then
    return { 'lsp', 'conform' }
  end

  if type(backend) == 'string' then
    if backend == 'lsp' or backend == 'conform' then
      return { backend }
    end
    logger:warn(("Invalid formatter backend `%s`; expected `lsp` or `conform`."):format(backend))
    return nil
  end

  if type(backend) == 'table' then
    local dedup = {}
    local out = {}
    for _, item in ipairs(backend) do
      if item == 'lsp' or item == 'conform' then
        if not dedup[item] then
          dedup[item] = true
          table.insert(out, item)
        end
      else
        logger:warn(("Ignoring invalid formatter backend `%s`."):format(tostring(item)))
      end
    end

    if #out == 0 then
      logger:warn('No valid formatter backends were provided.')
      return nil
    end

    return out
  end

  logger:warn('Invalid formatter backend input; expected string, table, or nil.')
  return nil
end

local function normalize_source(source)
  if source == 'lsp' or source == 'conform' then
    return source
  end

  logger:warn(("Invalid formatter source `%s`; expected `lsp` or `conform`."):format(tostring(source)))
  return nil
end

local function normalize_name(name)
  if type(name) == 'string' and name ~= '' then
    return name
  end

  logger:warn('Formatter item name must be a non-empty string.')
  return nil
end

local function normalize_scope_backends_bufnr(opts)
  opts = opts or {}
  local scope = resolve_scope(opts.scope)
  if not scope then
    return nil
  end

  local backends = normalize_backends(opts.backend)
  if not backends then
    return nil
  end

  local bufnr = resolve_bufnr(opts.bufnr)
  return {
    scope = scope,
    backends = backends,
    bufnr = bufnr,
  }
end

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

local function get_effective_backend_state(backend, scope, bufnr)
  if scope == 'global' then
    return state.global.backends[backend]
  end

  local buf_state = get_buffer_state(bufnr, false)
  if buf_state and buf_state.backends[backend] ~= nil then
    return buf_state.backends[backend]
  end

  return state.global.backends[backend]
end

local function set_backend_state(backend, scope, bufnr, enabled)
  if scope == 'global' then
    state.global.backends[backend] = enabled
    return
  end

  local buf_state = get_buffer_state(bufnr, true)
  buf_state.backends[backend] = enabled
  compact_buffer_state(bufnr)
end

local function clear_backend_state(backend, scope, bufnr)
  if scope == 'global' then
    state.global.backends[backend] = default_backend_state[backend]
    return
  end

  local buf_state = get_buffer_state(bufnr, false)
  if not buf_state then
    return
  end

  buf_state.backends[backend] = nil
  compact_buffer_state(bufnr)
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

local function get_effective_item_state(source, name, scope, bufnr)
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

local function set_item_state(source, name, scope, bufnr, enabled)
  local item_map = get_scope_item_map(scope, bufnr, source, true)
  item_map[name] = enabled
  if scope == 'buffer' then
    compact_buffer_state(bufnr)
  end
end

local function clear_item_state(source, name, scope, bufnr)
  local item_map = get_scope_item_map(scope, bufnr, source, false)
  if not item_map then
    return
  end

  item_map[name] = nil
  if scope == 'buffer' then
    compact_buffer_state(bufnr)
  end
end

local function clear_source_items(source, scope, bufnr)
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

local function current_buffer_has_backend_override(backends, bufnr)
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

local function notify_global_override(backends)
  local bufnr = vim.api.nvim_get_current_buf()
  if current_buffer_has_backend_override(backends, bufnr) then
    logger:warn('Global formatter state changed, but this buffer has local formatter overrides.')
  end
end

local function get_devicons()
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    logger:error('nvim-web-devicons is required for cosmic-ui formatters UI.')
    return nil
  end

  return devicons
end

local function get_conform_module()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return nil
  end
  return conform
end

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

  return 'no formatting support'
end

local function normalize_formatter_name(entry)
  if type(entry) == 'string' then
    return entry
  end

  if type(entry) == 'table' then
    if type(entry.name) == 'string' and entry.name ~= '' then
      return entry.name
    end

    if type(entry.id) == 'string' and entry.id ~= '' then
      return entry.id
    end
  end

  return nil
end

local function extract_formatter_names(raw)
  local names = {}
  local seen = {}

  local function add(name)
    if type(name) == 'string' and name ~= '' and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end

  local function parse_list(value)
    if type(value) ~= 'table' then
      return
    end

    if type(value.formatters) == 'table' then
      parse_list(value.formatters)
      return
    end

    if vim.islist(value) then
      for _, item in ipairs(value) do
        add(normalize_formatter_name(item))
      end
      return
    end

    add(normalize_formatter_name(value))
  end

  parse_list(raw)
  return names
end

local function get_conform_formatter_names(bufnr)
  local conform = get_conform_module()
  if not conform then
    return nil, 'conform_not_installed'
  end

  if type(conform.list_formatters_to_run) ~= 'function' then
    return {}, nil
  end

  local ok, first, second = pcall(conform.list_formatters_to_run, bufnr)
  if not ok then
    logger:error(('Conform formatter discovery failed: %s'):format(first))
    return {}, nil
  end

  local names = {}
  local seen = {}

  local function append(list)
    for _, name in ipairs(extract_formatter_names(list)) do
      if not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end
  end

  append(first)
  append(second)

  table.sort(names)
  return names, nil
end

local function get_lsp_items(bufnr, scope)
  local backend_enabled = get_effective_backend_state('lsp', scope, bufnr)
  local items = {}
  local enabled_ids = {}

  for _, client in ipairs(get_lsp_clients(bufnr)) do
    local reason = lsp_client_reason(client)
    local available = reason == nil
    local item_enabled = get_effective_item_state('lsp', client.name, scope, bufnr)
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

local function get_conform_items(bufnr, scope)
  local backend_enabled = get_effective_backend_state('conform', scope, bufnr)
  local names, reason = get_conform_formatter_names(bufnr)
  local items = {}

  if reason == 'conform_not_installed' then
    return {
      available = false,
      reason = 'conform not installed',
      items = items,
    }
  end

  for _, name in ipairs(names) do
    local item_enabled = get_effective_item_state('conform', name, scope, bufnr)
    table.insert(items, {
      name = name,
      available = true,
      enabled = item_enabled,
      effective_enabled = backend_enabled and item_enabled,
    })
  end

  return {
    available = true,
    reason = nil,
    items = items,
  }
end

local function lsp_backend_state(scope, bufnr)
  local backend_enabled = get_effective_backend_state('lsp', scope, bufnr)
  if not backend_enabled then
    return 'OFF', backend_enabled
  end

  local _, enabled_ids = get_lsp_items(bufnr, scope)
  if next(enabled_ids) == nil then
    return 'UNAVAILABLE', backend_enabled
  end

  return 'ON', backend_enabled
end

local function conform_backend_state(scope, bufnr)
  local backend_enabled = get_effective_backend_state('conform', scope, bufnr)
  if not backend_enabled then
    return 'OFF', backend_enabled
  end

  local conform_data = get_conform_items(bufnr, scope)
  if not conform_data.available then
    return 'UNAVAILABLE', backend_enabled
  end

  for _, item in ipairs(conform_data.items) do
    if item.effective_enabled then
      return 'ON', backend_enabled
    end
  end

  return 'UNAVAILABLE', backend_enabled
end

local function backend_summary(scope, bufnr)
  local lsp_state = lsp_backend_state(scope, bufnr)
  local conform_state = conform_backend_state(scope, bufnr)
  return ('Formatters [%s] lsp=%s conform=%s'):format(scope, lsp_state, conform_state)
end

local function mutate_backends(opts, mutator, action_name)
  local normalized = normalize_scope_backends_bufnr(opts)
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

local function normalize_item_opts(opts)
  opts = opts or {}

  local scope = resolve_scope(opts.scope)
  if not scope then
    return nil
  end

  local source = normalize_source(opts.source)
  if not source then
    return nil
  end

  local name = normalize_name(opts.name)
  if not name then
    return nil
  end

  return {
    scope = scope,
    source = source,
    name = name,
    bufnr = resolve_bufnr(opts.bufnr),
  }
end

local function mutate_item(opts, mutator, action_name)
  local normalized = normalize_item_opts(opts)
  if not normalized then
    return
  end

  mutator(normalized)

  logger:log(
    ('Formatters [%s] %s:%s=%s'):format(
      normalized.scope,
      normalized.source,
      normalized.name,
      tostring(get_effective_item_state(normalized.source, normalized.name, normalized.scope, normalized.bufnr))
    ),
    {
      title = ('Formatters: %s'):format(action_name),
    }
  )
end

local function run_conform(bufnr, scope, async, conform_opts, callback)
  local conform = get_conform_module()
  if not conform then
    warn_once('Conform.nvim not available; skipping conform formatter.')
    if callback then
      callback(false)
    end
    return false
  end

  local names = select(1, get_conform_formatter_names(bufnr)) or {}
  local allowed = {}
  for _, name in ipairs(names) do
    if get_effective_item_state('conform', name, scope, bufnr) then
      table.insert(allowed, name)
    end
  end

  local explicit = conform_opts and conform_opts.formatters or nil
  if type(explicit) == 'table' and #explicit > 0 then
    local explicit_set = {}
    for _, name in ipairs(explicit) do
      explicit_set[name] = true
    end

    local intersect = {}
    for _, name in ipairs(allowed) do
      if explicit_set[name] then
        table.insert(intersect, name)
      end
    end
    allowed = intersect
  end

  if #allowed == 0 then
    warn_once('Conform formatting unavailable (all conform formatters disabled or not runnable).')
    if callback then
      callback(false)
    end
    return false
  end

  local user_opts = vim.deepcopy(conform_opts or {})
  user_opts.formatters = nil

  local opts = utils.merge({
    bufnr = bufnr,
    async = async,
    lsp_fallback = false,
    lsp_format = 'never',
  }, user_opts)
  opts.formatters = allowed

  if async then
    local ok, err = pcall(conform.format, opts, function(format_err)
      if format_err then
        logger:error(('Conform format failed: %s'):format(format_err))
      end
      if callback then
        callback(true)
      end
    end)

    if not ok then
      logger:error(('Conform format failed: %s'):format(err))
      if callback then
        callback(false)
      end
      return false
    end

    return true
  end

  local ok, err = pcall(conform.format, opts)
  if not ok then
    logger:error(('Conform format failed: %s'):format(err))
    if callback then
      callback(false)
    end
    return false
  end

  if callback then
    callback(true)
  end
  return true
end

local function run_lsp(bufnr, scope, async, lsp_opts)
  local client_items, enabled_ids = get_lsp_items(bufnr, scope)
  if next(enabled_ids) == nil then
    if #client_items == 0 then
      logger:warn('LSP formatting unavailable (no clients attached).')
    else
      warn_once('LSP formatting unavailable (all attached clients disabled or unsupported).')
    end
    return false
  end

  lsp_opts = lsp_opts or {}
  local user_filter = type(lsp_opts.filter) == 'function' and lsp_opts.filter or nil
  local user_opts = vim.deepcopy(lsp_opts)
  user_opts.filter = nil

  local opts = utils.merge({
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

  local ok, err = pcall(vim.lsp.buf.format, opts)
  if not ok then
    logger:error(('LSP format failed: %s'):format(err))
    return false
  end

  return true
end

local function format_internal(opts, async)
  opts = opts or {}
  local scope = resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = resolve_bufnr(opts.bufnr)
  local requested = normalize_backends(opts.backend)
  if not requested then
    return
  end

  local requested_set = {}
  for _, backend in ipairs(requested) do
    requested_set[backend] = true
  end

  local should_run = {}
  for _, backend in ipairs(backend_order) do
    if requested_set[backend] and get_effective_backend_state(backend, scope, bufnr) then
      table.insert(should_run, backend)
    end
  end

  if #should_run == 0 then
    logger:warn('No enabled formatters available for this scope.')
    return false
  end

  local conform_opts = vim.deepcopy(opts.conform or {})
  local lsp_opts = vim.deepcopy(opts.lsp or {})
  local ran = false

  local function run_lsp_stage()
    for _, backend in ipairs(should_run) do
      if backend == 'lsp' then
        ran = run_lsp(bufnr, scope, async, lsp_opts) or ran
      end
    end
  end

  if async then
    for _, backend in ipairs(should_run) do
      if backend == 'conform' then
        local started = run_conform(bufnr, scope, true, conform_opts, function(did_run)
          ran = did_run or ran
          run_lsp_stage()
        end)

        if not started then
          run_lsp_stage()
        end

        return started or ran
      end
    end

    run_lsp_stage()
    return ran
  end

  for _, backend in ipairs(should_run) do
    if backend == 'conform' then
      ran = run_conform(bufnr, scope, false, conform_opts) or ran
    elseif backend == 'lsp' then
      ran = run_lsp(bufnr, scope, false, lsp_opts) or ran
    end
  end

  return ran
end

local function close_ui()
  local ui = state.ui
  if not ui then
    return
  end

  state.ui = nil

  if ui.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, ui.augroup)
  end

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    pcall(vim.api.nvim_win_close, ui.win, true)
  end

  if ui.buf and vim.api.nvim_buf_is_valid(ui.buf) then
    pcall(vim.api.nvim_buf_delete, ui.buf, { force = true })
  end
end

local function next_toggleable_index(rows, start_idx, step)
  if #rows == 0 then
    return nil
  end

  local idx = start_idx
  for _ = 1, #rows do
    idx = idx + step
    if idx < 1 then
      idx = #rows
    elseif idx > #rows then
      idx = 1
    end

    if rows[idx].toggleable then
      return idx
    end
  end

  return nil
end

local function ensure_selection(ui)
  if not ui.rows or #ui.rows == 0 then
    ui.selected = nil
    return
  end

  if ui.selected and ui.rows[ui.selected] and ui.rows[ui.selected].toggleable then
    return
  end

  for idx, row in ipairs(ui.rows) do
    if row.toggleable then
      ui.selected = idx
      return
    end
  end

  ui.selected = nil
end

local function set_cursor_to_selected(ui)
  if not ui.selected then
    return
  end

  local row = ui.rows and ui.rows[ui.selected]
  if not row then
    return
  end

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    pcall(vim.api.nvim_win_set_cursor, ui.win, { row.lnum, 0 })
  end
end

local function clamp_ui_size(width, height)
  local max_width = math.max(50, math.floor(vim.o.columns * 0.9))
  local max_height = math.max(14, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8))
  return math.min(width, max_width), math.min(height, max_height)
end

local function ensure_ui_highlights()
  if not state.ui_ns then
    state.ui_ns = vim.api.nvim_create_namespace('cosmic-ui-formatters')
  end

  for name, link in pairs(highlight_links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

local function find_token(line, token, init)
  if not line or not token or token == '' then
    return nil, nil
  end

  local start_idx, end_idx = line:find(token, init or 1, true)
  if not start_idx then
    return nil, nil
  end

  return start_idx - 1, end_idx
end

local function add_hl(bufnr, lnum, group, col_start, col_end)
  if not (group and col_start and col_end) then
    return
  end

  vim.api.nvim_buf_add_highlight(bufnr, state.ui_ns, group, lnum, col_start, col_end)
end

local function status_hl_group(status)
  if status == 'enabled' then
    return 'CosmicUiFmtEnabled'
  end
  if status == 'disabled' then
    return 'CosmicUiFmtDisabled'
  end
  return 'CosmicUiFmtUnavailable'
end

local function highlight_hint_keys(bufnr, line_no, line)
  local keys = {
    { key = '<tab>', token = '<tab>:' },
    { key = 's', token = 's:' },
    { key = 'r', token = 'r:' },
    { key = 'a', token = 'a:' },
    { key = 'f', token = 'f:' },
    { key = 'q', token = 'q:' },
  }
  add_hl(bufnr, line_no, 'CosmicUiFmtHintText', 0, -1)

  for _, entry in ipairs(keys) do
    local start_at = 1
    while true do
      local s_col, e_col = find_token(line, entry.token, start_at)
      if not s_col then
        break
      end
      add_hl(bufnr, line_no, 'CosmicUiFmtHintKey', s_col, s_col + #entry.key)
      start_at = e_col + 1
    end
  end
end

local function make_icons(devicons, bufnr)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local file_name = vim.fn.fnamemodify(file_path, ':t')
  if file_name == '' then
    file_name = 'file.txt'
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    filetype = 'text'
  end

  local ext = vim.fn.fnamemodify(file_name, ':e')
  local file_icon
  if type(devicons.get_icon_by_filetype) == 'function' then
    file_icon = devicons.get_icon_by_filetype(filetype, { default = true })
  end
  if not file_icon then
    file_icon = devicons.get_icon(file_name, ext, { default = true })
  end
  local lsp_icon = devicons.get_icon('lsp.lua', 'lua', { default = true })
  local conform_icon = devicons.get_icon('conform.lua', 'lua', { default = true })

  return {
    file = file_icon or '*',
    filetype = filetype,
    lsp = lsp_icon or '*',
    conform = conform_icon or '*',
  }
end

local function build_rows(ui, status, icons)
  local rows = {}

  table.insert(rows, {
    id = 'section_conform',
    text = 'Conform',
    toggleable = false,
    kind = 'section',
  })

  if not status.conform.available then
    table.insert(rows, {
      id = 'conform_unavailable',
      text = ('%s %s %s'):format(status_icons.unavailable, icons.conform, status.conform.reason or 'unavailable'),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.conform,
    })
  elseif #status.conform.formatters == 0 then
    table.insert(rows, {
      id = 'conform_empty',
      text = ('%s %s no formatters to run'):format(status_icons.unavailable, icons.conform),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.conform,
    })
  else
    for _, formatter in ipairs(status.conform.formatters) do
      local row_status = formatter.enabled and 'enabled' or 'disabled'
      local status_icon = status_icons[row_status]
      table.insert(rows, {
        id = 'conform_' .. formatter.name,
        text = ('%s %s %s'):format(status_icon, icons.conform, formatter.name),
        toggleable = true,
        kind = 'item',
        status = row_status,
        status_icon = status_icon,
        source_icon = icons.conform,
        action = {
          kind = 'item',
          source = 'conform',
          name = formatter.name,
        },
      })
    end
  end

  table.insert(rows, {
    id = 'section_lsp',
    text = 'LSP',
    toggleable = false,
    kind = 'section',
  })

  if #status.lsp_clients == 0 then
    table.insert(rows, {
      id = 'lsp_empty',
      text = ('%s %s no attached clients'):format(status_icons.unavailable, icons.lsp),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.lsp,
    })
  else
    for _, client in ipairs(status.lsp_clients) do
      local row_status = client.available and (client.enabled and 'enabled' or 'disabled') or 'unavailable'
      local status_icon = status_icons[row_status]
      local suffix = ''
      if not client.available and client.reason then
        suffix = (' (%s)'):format(client.reason)
      end

      table.insert(rows, {
        id = 'lsp_' .. client.name,
        text = ('%s %s LSP: %s%s'):format(status_icon, icons.lsp, client.name, suffix),
        toggleable = client.available,
        kind = 'item',
        status = row_status,
        status_icon = status_icon,
        source_icon = icons.lsp,
        reason = client.reason,
        action = {
          kind = 'item',
          source = 'lsp',
          name = client.name,
        },
      })
    end
  end

  return rows
end

local function apply_ui_highlights(ui, lines)
  if not ui.buf or not vim.api.nvim_buf_is_valid(ui.buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(ui.buf, state.ui_ns, 0, -1)

  local header_lnum = ui.header_lnum
  if header_lnum and lines[header_lnum] then
    add_hl(ui.buf, header_lnum - 1, 'CosmicUiFmtHeader', 0, -1)
    local icon_start, icon_end = find_token(lines[header_lnum], ui.icons.file, 1)
    add_hl(ui.buf, header_lnum - 1, 'CosmicUiFmtIcon', icon_start, icon_end)
  end

  for _, row in ipairs(ui.rows) do
    local line = lines[row.lnum]
    local lnum = row.lnum - 1
    if row.kind == 'section' then
      add_hl(ui.buf, lnum, 'CosmicUiFmtSection', 0, -1)
    else
      local status_start, status_end = find_token(line, row.status_icon, 1)
      add_hl(ui.buf, lnum, status_hl_group(row.status), status_start, status_end)

      local icon_start, icon_end = find_token(line, row.source_icon, (status_end or 0) + 1)
      add_hl(ui.buf, lnum, 'CosmicUiFmtIcon', icon_start, icon_end)

      if row.reason then
        local reason_text = ('(%s)'):format(row.reason)
        local reason_start, reason_end = find_token(line, reason_text, (icon_end or 0) + 1)
        add_hl(ui.buf, lnum, 'CosmicUiFmtUnavailable', reason_start, reason_end)
      end
    end
  end

  if ui.footer_lnum then
    local footer = lines[ui.footer_lnum]
    highlight_hint_keys(ui.buf, ui.footer_lnum - 1, footer)
  end
end

local function render_ui(ui)
  if not ui.buf or not vim.api.nvim_buf_is_valid(ui.buf) then
    return
  end

  local devicons = get_devicons()
  if not devicons then
    close_ui()
    return
  end
  ensure_ui_highlights()

  local status = M.status({ scope = ui.scope, bufnr = ui.target_bufnr })
  if not status then
    return
  end

  local icons = make_icons(devicons, ui.target_bufnr)
  local rows = build_rows(ui, status, icons)

  ui.rows = rows
  ensure_selection(ui)

  local header_left = ('%s %s'):format(icons.file, icons.filetype)
  local header_right = ui.scope
  local content_lines = {}
  local header_bottom_padding = 1
  local max_content_width = vim.fn.strdisplaywidth(header_left) + 1 + vim.fn.strdisplaywidth(header_right)

  table.insert(content_lines, '')
  ui.header_lnum = 1
  for _ = 1, header_bottom_padding do
    table.insert(content_lines, '')
  end

  max_content_width = math.max(max_content_width, vim.fn.strdisplaywidth(''))
  for idx, row in ipairs(rows) do
    table.insert(content_lines, row.text)
    max_content_width = math.max(max_content_width, vim.fn.strdisplaywidth(row.text))
    row.lnum = #content_lines
  end

  table.insert(content_lines, '')
  max_content_width = math.max(max_content_width, vim.fn.strdisplaywidth(''))
  table.insert(content_lines, '<tab>:toggle  s:switch scope  r:reset  a:toggle all  f:format  q:close')
  max_content_width = math.max(max_content_width, vim.fn.strdisplaywidth(content_lines[#content_lines]))
  ui.footer_lnum = #content_lines

  local gap = max_content_width - vim.fn.strdisplaywidth(header_left) - vim.fn.strdisplaywidth(header_right)
  if gap < 1 then
    gap = 1
  end
  content_lines[ui.header_lnum] = header_left .. string.rep(' ', gap) .. header_right

  local lines = {}
  for _ = 1, ui_padding.y do
    table.insert(lines, '')
  end

  local left_pad = string.rep(' ', ui_padding.x)
  for _, line in ipairs(content_lines) do
    table.insert(lines, left_pad .. line)
  end

  for _ = 1, ui_padding.y do
    table.insert(lines, '')
  end

  for _, row in ipairs(rows) do
    row.lnum = row.lnum + ui_padding.y
  end
  ui.header_lnum = ui.header_lnum + ui_padding.y
  ui.footer_lnum = ui.footer_lnum + ui_padding.y

  local max_height = math.max(14, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8))
  if #lines > max_height then
    lines = vim.list_slice(lines, 1, max_height)
    lines[#lines] = '...'
  end

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.max(width + 2, 64)
  local height = #lines
  width, height = clamp_ui_size(width, height)

  local row = math.max(1, math.floor(((vim.o.lines - vim.o.cmdheight) - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local border = vim.o.winborder ~= '' and vim.o.winborder or nil
  local win_config = {
    relative = 'editor',
    style = 'minimal',
    border = border,
    title = ' CosmicNvim Format ',
    title_pos = 'center',
    row = row,
    col = col,
    width = width,
    height = height,
  }

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    vim.api.nvim_win_set_config(ui.win, win_config)
  end

  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, lines)
  vim.bo[ui.buf].modifiable = false
  ui.icons = icons
  apply_ui_highlights(ui, lines)

  set_cursor_to_selected(ui)
end

local function move_selection(ui, delta)
  if not ui.rows or #ui.rows == 0 then
    return
  end

  local start = ui.selected or 1
  local next_idx = next_toggleable_index(ui.rows, start, delta)
  if next_idx then
    ui.selected = next_idx
    set_cursor_to_selected(ui)
  end
end

local function toggle_action(action, ui)
  if not action or action.kind ~= 'item' then
    return
  end

  local current = get_effective_item_state(action.source, action.name, ui.scope, ui.target_bufnr)
  set_item_state(action.source, action.name, ui.scope, ui.target_bufnr, not current)
end

local function toggle_row(ui)
  if not ui.selected then
    return
  end

  local row = ui.rows and ui.rows[ui.selected]
  if not row or not row.toggleable then
    return
  end

  toggle_action(row.action, ui)
  render_ui(ui)
end

local function toggle_all_rows(ui)
  if not ui.rows then
    return
  end

  local toggleable = {}
  for _, row in ipairs(ui.rows) do
    if row.toggleable and row.action and row.action.kind == 'item' then
      table.insert(toggleable, row)
    end
  end

  if #toggleable == 0 then
    return
  end

  local all_enabled = true
  for _, row in ipairs(toggleable) do
    local is_enabled = M.is_item_enabled({
      scope = ui.scope,
      bufnr = ui.target_bufnr,
      source = row.action.source,
      name = row.action.name,
    })

    if not is_enabled then
      all_enabled = false
      break
    end
  end

  for _, row in ipairs(toggleable) do
    if all_enabled then
      set_item_state(row.action.source, row.action.name, ui.scope, ui.target_bufnr, false)
    else
      set_item_state(row.action.source, row.action.name, ui.scope, ui.target_bufnr, true)
    end
  end

  render_ui(ui)
end

local function set_ui_keymaps(ui)
  local function map(lhs, rhs)
    vim.keymap.set('n', lhs, rhs, { buffer = ui.buf, silent = true, nowait = true })
  end

  map('j', function()
    move_selection(ui, 1)
  end)
  map('<Down>', function()
    move_selection(ui, 1)
  end)

  map('k', function()
    move_selection(ui, -1)
  end)
  map('<Up>', function()
    move_selection(ui, -1)
  end)

  map('<Tab>', function()
    toggle_row(ui)
  end)

  map('a', function()
    toggle_all_rows(ui)
  end)

  map('r', function()
    M.reset({ scope = ui.scope, bufnr = ui.target_bufnr })
    render_ui(ui)
  end)

  map('s', function()
    ui.scope = (ui.scope == 'buffer') and 'global' or 'buffer'
    render_ui(ui)
  end)

  map('f', function()
    M.format_async({ scope = ui.scope, bufnr = ui.target_bufnr })
    close_ui()
  end)

  map('<CR>', close_ui)
  map('<Esc>', close_ui)
  map('q', close_ui)
end

M.open = function(opts)
  opts = opts or {}
  close_ui()

  local devicons = get_devicons()
  if not devicons then
    return
  end
  ensure_ui_highlights()

  local scope = resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = resolve_bufnr(opts.bufnr)
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    return
  end

  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'cosmicui-formatters'

  local border = vim.o.winborder ~= '' and vim.o.winborder or nil
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = border,
    title = ' CosmicNvim Format ',
    title_pos = 'center',
    row = 2,
    col = 4,
    width = 64,
    height = 14,
  })

  if not win then
    return
  end

  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false
  vim.wo[win].winhl = 'FloatTitle:CosmicUiFmtTitle,FloatBorder:CosmicUiFmtSection'

  local ui = {
    scope = scope,
    target_bufnr = bufnr,
    buf = buf,
    win = win,
    selected = nil,
    rows = {},
  }

  ui.augroup = vim.api.nvim_create_augroup('cosmic_ui_formatters_' .. tostring(buf), { clear = true })
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    group = ui.augroup,
    buffer = buf,
    callback = function()
      close_ui()
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = ui.augroup,
    pattern = tostring(win),
    callback = function()
      close_ui()
    end,
  })

  state.ui = ui
  set_ui_keymaps(ui)
  render_ui(ui)
end

M.toggle = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    local current = get_effective_backend_state(backend, scope, bufnr)
    set_backend_state(backend, scope, bufnr, not current)
  end, 'toggle')
end

M.enable = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    set_backend_state(backend, scope, bufnr, true)
  end, 'enable')
end

M.disable = function(opts)
  mutate_backends(opts, function(backend, scope, bufnr)
    set_backend_state(backend, scope, bufnr, false)
  end, 'disable')
end

M.toggle_item = function(opts)
  mutate_item(opts, function(item)
    local current = get_effective_item_state(item.source, item.name, item.scope, item.bufnr)
    set_item_state(item.source, item.name, item.scope, item.bufnr, not current)
  end, 'toggle_item')
end

M.enable_item = function(opts)
  mutate_item(opts, function(item)
    set_item_state(item.source, item.name, item.scope, item.bufnr, true)
  end, 'enable_item')
end

M.disable_item = function(opts)
  mutate_item(opts, function(item)
    set_item_state(item.source, item.name, item.scope, item.bufnr, false)
  end, 'disable_item')
end

M.is_item_enabled = function(opts)
  local normalized = normalize_item_opts(opts)
  if not normalized then
    return
  end

  return get_effective_item_state(normalized.source, normalized.name, normalized.scope, normalized.bufnr)
end

M.reset = function(opts)
  opts = opts or {}

  local scope = resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = resolve_bufnr(opts.bufnr)

  if opts.source ~= nil then
    local source = normalize_source(opts.source)
    if not source then
      return
    end

    if opts.name ~= nil then
      local name = normalize_name(opts.name)
      if not name then
        return
      end
      clear_item_state(source, name, scope, bufnr)
    else
      clear_source_items(source, scope, bufnr)
    end

    logger:log(('Formatters [%s] reset %s item overrides'):format(scope, source), {
      title = 'Formatters: reset',
    })
    return
  end

  local backends = normalize_backends(opts.backend)
  if not backends then
    return
  end

  for _, backend in ipairs(backends) do
    clear_backend_state(backend, scope, bufnr)
  end

  if opts.backend == nil then
    clear_source_items('lsp', scope, bufnr)
    clear_source_items('conform', scope, bufnr)
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

  local scope = resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = resolve_bufnr(opts.bufnr)
  if opts.backend ~= nil then
    local backends = normalize_backends(opts.backend)
    if not backends then
      return
    end

    if #backends == 1 then
      return get_effective_backend_state(backends[1], scope, bufnr)
    end
  end

  return {
    lsp = get_effective_backend_state('lsp', scope, bufnr),
    conform = get_effective_backend_state('conform', scope, bufnr),
  }
end

M.status = function(opts)
  opts = opts or {}

  local scope = resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = resolve_bufnr(opts.bufnr)

  local lsp_state, lsp_enabled = lsp_backend_state(scope, bufnr)
  local conform_state, conform_enabled = conform_backend_state(scope, bufnr)
  local lsp_clients = get_lsp_items(bufnr, scope)
  local conform_data = get_conform_items(bufnr, scope)

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
    },
  }
end

M.format = function(opts)
  return format_internal(opts, false)
end

M.format_async = function(opts)
  return format_internal(opts, true)
end

return M
