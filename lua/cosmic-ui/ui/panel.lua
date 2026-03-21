local highlights = require('cosmic-ui.ui.highlights')
local window = require('cosmic-ui.window')

local M = {}

local function normalize_footer_entry(entry)
  if type(entry) == 'table' then
    return {
      key = entry.key or entry[1] or '',
      text = entry.text or entry[2] or '',
    }
  end

  local raw = tostring(entry or '')
  local key, text = raw:match('^([^:]+):%s*(.+)$')
  if key then
    return { key = key, text = text }
  end

  return { key = raw, text = '' }
end

local function normalize_footer(entries)
  local footer = {}

  for _, entry in ipairs(entries or {}) do
    table.insert(footer, normalize_footer_entry(entry))
  end

  return footer
end

local function normalize_row(row)
  local normalized = vim.tbl_extend('force', {}, row or {})

  if normalized.kind == 'state' then
    normalized.state = normalized.state or 'info'
    normalized.text = normalized.text or ''
    normalized.highlight = highlights.group_for_state(normalized.state)
  end

  return normalized
end

local function normalize_rows(rows)
  local normalized = {}

  for _, row in ipairs(rows or {}) do
    table.insert(normalized, normalize_row(row))
  end

  return normalized
end

local function normalize_selected(selected, rows)
  if type(selected) ~= 'number' then
    return nil
  end

  selected = math.floor(selected)
  if selected < 1 or selected > #rows then
    return nil
  end

  return selected
end

function M.build(opts)
  opts = opts or {}
  local rows = normalize_rows(opts.rows)

  return {
    title = opts.title or '',
    subtitle = opts.subtitle or '',
    footer = normalize_footer(opts.footer),
    rows = rows,
    selected = normalize_selected(opts.selected, rows),
  }
end

function M.prepare(opts)
  highlights.ensure()
  return M.build(opts)
end

M.restore_focus = window.restore_focus

return M
