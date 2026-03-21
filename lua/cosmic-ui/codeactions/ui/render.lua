local M = {}

local function clamp_ui_size(width, height)
  local max_width = math.max(36, math.floor(vim.o.columns * 0.9))
  local max_height = math.max(8, math.floor((vim.o.lines - vim.o.cmdheight) * 0.7))
  return math.min(width, max_width), math.min(height, max_height)
end

local function footer_line(entries)
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

M.ensure_selection = function(ui)
  if #ui.model.actions == 0 then
    ui.selected = nil
    return
  end

  if ui.selected and ui.selected >= 1 and ui.selected <= #ui.model.actions then
    return
  end

  ui.selected = 1
end

M.render = function(ui)
  if not (ui.buf and vim.api.nvim_buf_is_valid(ui.buf)) then
    return
  end

  M.ensure_selection(ui)

  local panel = ui.panel or {}
  local lines = {}
  local highlights = {}
  local action_line_by_idx = {}
  local max_width = 30
  local action_idx = 0

  local function push_line(text, meta)
    table.insert(lines, text)
    if meta then
      highlights[#lines] = meta
    end
    max_width = math.max(max_width, vim.fn.strdisplaywidth(text))
  end

  if panel.title and panel.title ~= '' then
    push_line(' ' .. panel.title .. ' ', { highlight = panel.title_highlight or 'CosmicUiPanelTitle' })
  end
  if panel.subtitle and panel.subtitle ~= '' then
    push_line(' ' .. panel.subtitle .. ' ', { highlight = panel.subtitle_highlight or 'CosmicUiPanelSubtitle' })
  end

  if #lines > 0 and panel.rows and #panel.rows > 0 then
    push_line('')
  end

  for _, row in ipairs(panel.rows or {}) do
    if row.kind == 'section' or row.kind == 'separator' then
      push_line(' ' .. row.text .. ' ', { highlight = 'CosmicUiPanelSection' })
    elseif row.kind == 'state' then
      push_line(' ' .. row.text .. ' ', { highlight = row.highlight or 'CosmicUiPanelStateInfo' })
    elseif row.kind == 'action' then
      action_idx = action_idx + 1
      push_line(' ' .. row.text .. ' ')
      action_line_by_idx[action_idx] = #lines
    else
      push_line(' ' .. (row.text or '') .. ' ')
    end
  end

  if panel.footer and #panel.footer > 0 then
    if #lines > 0 then
      push_line('')
    end
    local footer_text, spans = footer_line(panel.footer)
    for _, span in ipairs(spans) do
      span.start_col = span.start_col + 1
      span.end_col = span.end_col + 1
    end
    push_line(' ' .. footer_text .. ' ', { spans = spans })
  end

  local width, height = clamp_ui_size(math.max(max_width, (ui.min_width or 30) + 2), math.max(#lines, 1))
  local indicator = nil
  if #ui.model.actions > 0 then
    indicator = ('(%d/%d)'):format(ui.selected or 0, #ui.model.actions)
  end

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    local cfg = vim.api.nvim_win_get_config(ui.win)
    cfg.width = width
    cfg.height = height
    cfg.title = ui.border and ui.border.title or nil
    cfg.title_pos = ui.border and ui.border.title_align or nil
    cfg.footer = indicator
    cfg.footer_pos = indicator and 'right' or nil
    vim.api.nvim_win_set_config(ui.win, cfg)
  end

  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, lines)
  vim.bo[ui.buf].modifiable = false

  local ns = ui.ns
  vim.api.nvim_buf_clear_namespace(ui.buf, ns, 0, -1)

  for line_no, meta in pairs(highlights) do
    if meta.highlight then
      vim.api.nvim_buf_add_highlight(ui.buf, ns, meta.highlight, line_no - 1, 0, -1)
    end

    for _, span in ipairs(meta.spans or {}) do
      if span.end_col >= span.start_col then
        vim.api.nvim_buf_add_highlight(ui.buf, ns, span.highlight, line_no - 1, span.start_col, span.end_col)
      end
    end
  end

  ui.action_line_by_idx = action_line_by_idx

  if ui.selected and ui.action_line_by_idx[ui.selected] and ui.win and vim.api.nvim_win_is_valid(ui.win) then
    pcall(vim.api.nvim_win_set_cursor, ui.win, { ui.action_line_by_idx[ui.selected], 0 })
  end
end

return M
