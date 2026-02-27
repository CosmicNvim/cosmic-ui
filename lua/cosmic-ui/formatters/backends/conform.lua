local constants = require('cosmic-ui.formatters.constants')
local state = require('cosmic-ui.formatters.state')
local lsp_backend = require('cosmic-ui.formatters.backends.lsp')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

M.get_conform_module = function()
  local ok, conform = pcall(require, 'conform')
  if not ok then
    return nil
  end
  return conform
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

M.get_conform_formatter_names = function(bufnr)
  local conform = M.get_conform_module()
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

local function normalize_lsp_format_mode(mode)
  if type(mode) == 'string' and constants.lsp_format_modes[mode] then
    return mode
  end
  return nil
end

M.resolve_conform_mode_sources = function(bufnr, requested_mode)
  local out = {
    available = false,
    requested_mode = normalize_lsp_format_mode(requested_mode),
    global_mode = nil,
    specific_mode = nil,
    specific_filetype = nil,
  }

  local conform = M.get_conform_module()
  if not conform then
    return out
  end

  out.available = true
  if type(conform.default_format_opts) == 'table' then
    out.global_mode = normalize_lsp_format_mode(conform.default_format_opts.lsp_format)
  end

  local by_ft = type(conform.formatters_by_ft) == 'table' and conform.formatters_by_ft or nil
  if not by_ft then
    return out
  end

  local filetype = vim.bo[bufnr].filetype
  local filetypes = vim.split(filetype, '.', { plain = true })
  local rev_filetypes = { filetype }
  for i = #filetypes, 1, -1 do
    table.insert(rev_filetypes, filetypes[i])
  end
  table.insert(rev_filetypes, '_')

  for _, candidate in ipairs(rev_filetypes) do
    local ft_formatters = by_ft[candidate]
    if ft_formatters ~= nil then
      local has_config = false
      local specific_mode = nil

      if type(ft_formatters) == 'function' then
        has_config = true
        local ok, value = pcall(ft_formatters, bufnr)
        if ok and type(value) == 'table' then
          specific_mode = normalize_lsp_format_mode(value.lsp_format)
        end
      elseif type(ft_formatters) == 'table' then
        has_config = next(ft_formatters) ~= nil
        if has_config then
          specific_mode = normalize_lsp_format_mode(ft_formatters.lsp_format)
        end
      else
        has_config = true
      end

      if has_config then
        out.specific_filetype = candidate
        out.specific_mode = specific_mode
        break
      end
    end
  end

  return out
end

M.resolve_configured_conform_lsp_mode = function(mode_sources)
  local mode
  local source
  if mode_sources.requested_mode then
    mode = mode_sources.requested_mode
    source = 'requested'
  elseif mode_sources.specific_mode then
    mode = mode_sources.specific_mode
    source = 'specific'
  elseif mode_sources.global_mode then
    mode = mode_sources.global_mode
    source = 'global'
  else
    mode = 'never'
    source = 'default'
  end
  return mode, source
end

M.resolve_effective_conform_lsp_mode = function(mode_sources, lsp_enabled)
  local configured_mode, configured_source = M.resolve_configured_conform_lsp_mode(mode_sources)
  local mode = configured_mode
  local source = configured_source
  if not lsp_enabled then
    mode = 'never'
    source = 'clamped'
  end

  return mode, source, configured_mode, configured_source
end

M.conform_mode_uses_lsp = function(mode, any_formatters)
  if mode == 'never' then
    return false
  end
  if not any_formatters then
    return true
  end
  if mode == 'fallback' then
    return false
  end
  return true
end

M.get_conform_items = function(bufnr, scope)
  local backend_enabled = state.get_effective_backend_state('conform', scope, bufnr)
  local names, reason = M.get_conform_formatter_names(bufnr)
  local items = {}

  if reason == 'conform_not_installed' then
    return {
      available = false,
      reason = 'conform not installed',
      items = items,
    }
  end

  for _, name in ipairs(names) do
    local item_enabled = state.get_effective_item_state('conform', name, scope, bufnr)
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

M.conform_backend_state = function(scope, bufnr)
  local backend_enabled = state.get_effective_backend_state('conform', scope, bufnr)
  if not backend_enabled then
    return 'OFF', backend_enabled
  end

  local conform_data = M.get_conform_items(bufnr, scope)
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

M.run_conform = function(opts)
  local conform = opts.conform
  local bufnr = opts.bufnr
  local scope = opts.scope
  local async = opts.async
  local conform_opts = opts.conform_opts
  local lsp_enabled = opts.lsp_enabled
  local warn_once = opts.warn_once

  local names = select(1, M.get_conform_formatter_names(bufnr)) or {}
  local allowed = {}
  for _, name in ipairs(names) do
    if state.get_effective_item_state('conform', name, scope, bufnr) then
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

  local mode_sources = M.resolve_conform_mode_sources(bufnr, conform_opts and conform_opts.lsp_format)
  local effective_lsp_format = select(1, M.resolve_effective_conform_lsp_mode(mode_sources, lsp_enabled))
  local any_formatters = #allowed > 0
  local can_use_lsp = M.conform_mode_uses_lsp(effective_lsp_format, any_formatters)

  local user_opts = vim.deepcopy(conform_opts or {})
  local user_filter = type(user_opts.filter) == 'function' and user_opts.filter or nil
  user_opts.formatters = nil
  user_opts.filter = nil
  if #allowed == 0 and not can_use_lsp then
    if warn_once then
      warn_once('Conform formatting unavailable (all conform formatters disabled or not runnable).')
    end
    return false
  end

  local merged = opts.merge_fn or function(left, right)
    return vim.tbl_deep_extend('force', left, right)
  end

  local format_opts = merged({
    bufnr = bufnr,
    async = async,
    lsp_fallback = false,
    lsp_format = effective_lsp_format,
  }, user_opts)
  format_opts.formatters = allowed

  if lsp_enabled and effective_lsp_format ~= 'never' then
    local _, enabled_ids = lsp_backend.get_lsp_items(bufnr, scope)
    format_opts.filter = function(client)
      if not enabled_ids[client.id] then
        return false
      end
      if user_filter then
        return user_filter(client)
      end
      return true
    end
  elseif user_filter and effective_lsp_format ~= 'never' then
    format_opts.filter = user_filter
  end

  if async then
    local ok, err = pcall(conform.format, format_opts, function(format_err)
      if format_err then
        logger:error(('Conform format failed: %s'):format(format_err))
      end
    end)

    if not ok then
      logger:error(('Conform format failed: %s'):format(err))
      return false
    end

    return true
  end

  local ok, err = pcall(conform.format, format_opts)
  if not ok then
    logger:error(('Conform format failed: %s'):format(err))
    return false
  end

  return true
end

return M
