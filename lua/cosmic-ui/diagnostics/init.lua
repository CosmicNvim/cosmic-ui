local config = require('cosmic-ui.config')
local guard = require('cosmic-ui.guard')
local utils = require('cosmic-ui.utils')
local window = require('cosmic-ui.window')
local logger = utils.Logger

local M = {}

local severity_name_to_value = {
  error = vim.diagnostic.severity.ERROR,
  warn = vim.diagnostic.severity.WARN,
  warning = vim.diagnostic.severity.WARN,
  info = vim.diagnostic.severity.INFO,
  hint = vim.diagnostic.severity.HINT,
}

local severity_value_to_prefix = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN] = 'W',
  [vim.diagnostic.severity.INFO] = 'I',
  [vim.diagnostic.severity.HINT] = 'H',
}

local severity_value_to_loclist_type = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN] = 'W',
  [vim.diagnostic.severity.INFO] = 'I',
  [vim.diagnostic.severity.HINT] = 'I',
}

local function normalize_severity(severity)
  if severity == nil then
    return nil
  end

  if type(severity) == 'number' then
    return severity
  end

  if type(severity) ~= 'string' then
    return nil
  end

  return severity_name_to_value[string.lower(severity)]
end

local function normalize_scope(scope)
  if scope == nil then
    return 'buffer'
  end

  if scope == 'buffer' or scope == 'workspace' then
    return scope
  end

  return nil
end

local function resolve_bufnr(bufnr)
  local resolved = bufnr
  if resolved == nil then
    resolved = 0
  end

  if resolved == 0 then
    resolved = vim.api.nvim_get_current_buf()
  end

  if type(resolved) ~= 'number' or resolved < 1 or not vim.api.nvim_buf_is_valid(resolved) then
    return nil
  end

  return resolved
end

local function sanitize_message(message)
  return (message or ''):gsub('\r', ' '):gsub('\n', ' '):gsub('%s+', ' ')
end

local function diagnostics_title(opts, total_count)
  local scope_label = opts.scope == 'workspace' and 'workspace' or 'buffer'
  local severity_label = ''
  if opts.severity ~= nil then
    severity_label = (' severity=%s'):format(severity_value_to_prefix[opts.severity] or tostring(opts.severity))
  end

  return ('Diagnostics [%s]%s (%d)'):format(scope_label, severity_label, total_count)
end

local function relative_or_tail_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == nil or path == '' then
    return '[No Name]'
  end

  local relative = vim.fn.fnamemodify(path, ':.')
  if relative == '' or relative == '.' then
    return vim.fn.fnamemodify(path, ':t')
  end

  return relative
end

local function collect(opts)
  local severity = normalize_severity(opts.severity)
  if opts.severity ~= nil and severity == nil then
    logger:warn('Invalid diagnostics severity; expected number or one of: error, warn, info, hint')
    return {}
  end

  local diagnostics
  if opts.scope == 'workspace' then
    diagnostics = vim.diagnostic.get(nil, { severity = severity })
  else
    diagnostics = vim.diagnostic.get(opts.bufnr, { severity = severity })
  end

  table.sort(diagnostics, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity
    end
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  local max_items = tonumber(opts.max_items) or #diagnostics
  if max_items > 0 and #diagnostics > max_items then
    diagnostics = vim.list_slice(diagnostics, 1, max_items)
  end

  return diagnostics
end

local function format_line(item)
  local prefix = severity_value_to_prefix[item.severity] or '?'
  local path = relative_or_tail_path(item.bufnr)
  local source = item.source and item.source ~= '' and (' [%s]'):format(item.source) or ''
  return ('%s %s:%d:%d %s%s'):format(
    prefix,
    path,
    item.lnum + 1,
    item.col + 1,
    sanitize_message(item.message),
    source
  )
end

local function jump_to(item)
  if not (item and item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr)) then
    return
  end

  vim.api.nvim_set_current_buf(item.bufnr)
  vim.api.nvim_win_set_cursor(0, { item.lnum + 1, item.col })
  vim.cmd('normal! zz')
end

local function resolve_open_opts(user_opts)
  local module_opts = config.module_opts('diagnostics') or {}
  local opts = utils.merge({
    scope = module_opts.scope,
    severity = nil,
    bufnr = 0,
    max_items = module_opts.max_items,
  }, user_opts or {})

  local scope = normalize_scope(opts.scope)
  if not scope then
    logger:warn('diagnostics.open: `scope` must be "buffer" or "workspace"')
    return nil
  end

  opts.scope = scope
  opts.bufnr = resolve_bufnr(opts.bufnr)
  if opts.scope == 'buffer' and not opts.bufnr then
    logger:warn('diagnostics.open: invalid buffer')
    return nil
  end

  return opts
end

local function open_picker(opts)
  local module_opts = config.module_opts('diagnostics') or {}
  local border_opts = module_opts.border or {}
  local diagnostics = collect(opts)

  if #diagnostics == 0 then
    logger:log('No diagnostics found for current selection.')
    return
  end

  local lines = {
    diagnostics_title(opts, #diagnostics),
    'Enter: jump  r: refresh  q/Esc: close',
  }

  local line_to_item = {}
  for index, item in ipairs(diagnostics) do
    lines[#lines + 1] = format_line(item)
    line_to_item[index + 2] = item
  end

  local max_line_width = 0
  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  local configured_min_width = tonumber(module_opts.min_width)
  local width = max_line_width + 2
  if configured_min_width and configured_min_width > width then
    width = configured_min_width
  end

  local height = math.max(4, math.min(#lines, math.floor((vim.o.lines - vim.o.cmdheight) * 0.7)))
  local float_config = window.centered_float_config(width, height, {
    max_height = math.max(10, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8)),
  })

  local buf = window.create_scratch_buf({ modifiable = true, filetype = 'cosmicui-diagnostics' })
  if not buf then
    logger:error('Unable to open diagnostics window')
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = window.open_float(buf, {
    border = {
      border_opts.style or vim.o.winborder,
      border_opts.highlight,
    },
    title = border_opts.title or 'Diagnostics',
    title_pos = border_opts.title_align or 'center',
    width = float_config.width,
    height = float_config.height,
    row = float_config.row,
    col = float_config.col,
  })

  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'

  local function close_picker()
    window.safe_close_win(win)
    window.safe_delete_buf(buf)
  end

  local function refresh_picker()
    close_picker()
    vim.schedule(function()
      M.open(opts)
    end)
  end

  local function jump_selected()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local item = line_to_item[row]
    if not item then
      return
    end

    close_picker()
    vim.schedule(function()
      jump_to(item)
    end)
  end

  vim.keymap.set('n', '<Esc>', close_picker, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('n', 'q', close_picker, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('n', 'r', refresh_picker, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('n', '<CR>', jump_selected, { buffer = buf, silent = true, nowait = true })

  vim.api.nvim_win_set_cursor(win, { math.min(3, #lines), 0 })
end

M.open = function(opts)
  if not guard.can_run('diagnostics', 'diagnostics.open(...)') then
    return
  end

  if opts ~= nil and type(opts) ~= 'table' then
    error('diagnostics.open: invalid arguments')
  end

  local resolved_opts = resolve_open_opts(opts)
  if not resolved_opts then
    return
  end

  open_picker(resolved_opts)
end

M.setloclist = function(opts)
  if not guard.can_run('diagnostics', 'diagnostics.setloclist(...)') then
    return
  end

  if opts ~= nil and type(opts) ~= 'table' then
    error('diagnostics.setloclist: invalid arguments')
  end

  local resolved_opts = resolve_open_opts(opts)
  if not resolved_opts then
    return
  end

  local diagnostics = collect(resolved_opts)
  local items = {}
  for _, item in ipairs(diagnostics) do
    items[#items + 1] = {
      bufnr = item.bufnr,
      lnum = item.lnum + 1,
      col = item.col + 1,
      text = sanitize_message(item.message),
      type = severity_value_to_loclist_type[item.severity] or 'I',
    }
  end

  vim.fn.setloclist(0, {}, ' ', {
    title = diagnostics_title(resolved_opts, #items),
    items = items,
  })

  if #items == 0 then
    logger:log('Location list cleared: no diagnostics found for current selection.')
    return
  end

  vim.cmd('lopen')
  logger:log(('Loaded %d diagnostics into location list.'):format(#items))
end

return M
