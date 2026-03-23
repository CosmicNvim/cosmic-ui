local highlights = require('cosmic-ui.ui.highlights')
local window = require('cosmic-ui.window')

local M = {}

local function normalize_footer_entry(entry)
  if type(entry) == 'table' then
    return {
      key = entry.key or entry[1] or '',
      text = entry.text or entry[2] or '',
      key_highlight = entry.key_highlight or 'CosmicUiPanelHintKey',
      text_highlight = entry.text_highlight or 'CosmicUiPanelHintText',
    }
  end

  local raw = tostring(entry or '')
  local key, text = raw:match('^([^:]+):%s*(.+)$')
  if key then
    return {
      key = key,
      text = text,
      key_highlight = 'CosmicUiPanelHintKey',
      text_highlight = 'CosmicUiPanelHintText',
    }
  end

  return {
    key = raw,
    text = '',
    key_highlight = 'CosmicUiPanelHintKey',
    text_highlight = 'CosmicUiPanelHintText',
  }
end

local function normalize_footer(entries)
  local footer = {}

  for _, entry in ipairs(entries or {}) do
    table.insert(footer, normalize_footer_entry(entry))
  end

  return footer
end

function M.render_footer(entries)
  local text = ''
  local spans = {}
  local col = 0

  for idx, entry in ipairs(entries or {}) do
    if idx > 1 then
      text = text .. '  '
      col = col + 2
    end

    local key = entry.key or ''
    local hint = entry.text or ''

    text = text .. key
    table.insert(spans, {
      highlight = entry.key_highlight,
      start_col = col,
      end_col = col + #key,
    })
    col = col + #key

    if hint ~= '' then
      text = text .. ':' .. hint
      table.insert(spans, {
        highlight = entry.text_highlight,
        start_col = col + 1,
        end_col = col + 1 + #hint,
      })
      col = col + 1 + #hint
    end
  end

  return text, spans
end

local function finalize_standard_text(spec, width)
  local text = spec.text or ''
  if not spec.center then
    return text
  end

  local text_width = vim.fn.strdisplaywidth(text)
  if text_width >= width then
    return text
  end

  local total_padding = width - text_width
  local left_padding = math.floor(total_padding / 2)
  local right_padding = total_padding - left_padding
  return string.rep(' ', left_padding) .. text .. string.rep(' ', right_padding)
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

local function normalize_layout(layout)
  if layout == 'compact' then
    return 'compact'
  end

  return 'standard'
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
    layout = normalize_layout(opts.layout),
    title = opts.title or '',
    subtitle = opts.subtitle or '',
    title_highlight = 'CosmicUiPanelTitle',
    subtitle_highlight = 'CosmicUiPanelSubtitle',
    footer = normalize_footer(opts.footer),
    rows = rows,
    selected = normalize_selected(opts.selected, rows),
  }
end

function M.prepare(opts)
  highlights.ensure()
  return M.build(opts)
end

function M.prepare_standard(model, opts)
  model = model or {}
  opts = opts or {}

  local line_specs = {}
  local action_line_by_idx = {}
  local raw_max_width = 30
  local action_idx = 0
  local seen_section = false

  local function push_line(spec)
    spec = spec or { text = '' }
    table.insert(line_specs, spec)
    raw_max_width = math.max(raw_max_width, vim.fn.strdisplaywidth(spec.text or ''))
  end

  for _, row in ipairs(model.rows or {}) do
    if row.kind == 'section' or row.kind == 'separator' then
      if seen_section then
        push_line({ text = '' })
      end
      push_line({
        text = row.text or '',
        center = true,
        meta = { highlight = 'CosmicUiPanelSection' },
      })
      seen_section = true
    elseif row.kind == 'state' then
      push_line({
        text = ' ' .. row.text .. ' ',
        meta = { highlight = row.highlight or 'CosmicUiPanelStateInfo' },
      })
    elseif row.kind == 'action' then
      action_idx = action_idx + 1
      push_line({ text = ' ' .. row.text .. ' ' })
      action_line_by_idx[action_idx] = #line_specs
    else
      push_line({ text = ' ' .. (row.text or '') .. ' ' })
    end
  end

  if model.footer and #model.footer > 0 then
    if #line_specs > 0 then
      push_line({ text = '' })
    end

    local footer_text, spans = M.render_footer(model.footer)
    for _, span in ipairs(spans) do
      span.start_col = span.start_col + 1
      span.end_col = span.end_col + 1
    end

    push_line({
      text = ' ' .. footer_text .. ' ',
      meta = { spans = spans },
    })
  end

  local width = math.max(raw_max_width, (opts.min_width or 30) + 2)
  local height = math.max(#line_specs, 1)

  if opts.clamp_size then
    width, height = opts.clamp_size(width, height)
  end

  local lines = {}
  local highlights_by_line = {}

  for idx, spec in ipairs(line_specs) do
    lines[idx] = finalize_standard_text(spec, width)
    if spec.meta then
      highlights_by_line[idx] = spec.meta
    end
  end

  return {
    width = width,
    height = height,
    lines = lines,
    highlights = highlights_by_line,
    action_line_by_idx = action_line_by_idx,
  }
end

M.restore_focus = window.restore_focus

return M
