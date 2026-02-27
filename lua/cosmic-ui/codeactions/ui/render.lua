local M = {}

local function pad_right(text, width)
  local text_width = vim.fn.strdisplaywidth(text)
  if text_width >= width then
    return text
  end
  return text .. string.rep(' ', width - text_width)
end

local function bordered_header(text, width)
  local label = text
  local label_width = vim.fn.strdisplaywidth(label)
  if label_width >= width then
    return label, 0, #label
  end

  -- Draw a simple section divider line: "──── (client) ────"
  local pad = width - label_width
  local left = math.floor(pad / 2)
  local right = pad - left

  local left_fill = (left > 0) and (string.rep('─', math.max(left - 1, 0)) .. ' ') or ''
  local right_fill = (right > 0) and (' ' .. string.rep('─', math.max(right - 1, 0))) or ''
  local rendered = left_fill .. label .. right_fill
  local label_start = #left_fill
  local label_end = label_start + #label
  return rendered, label_start, label_end
end

local function next_selected(ui)
  if ui.selected and ui.selected >= 1 and ui.selected <= #ui.model.actions then
    return ui.selected
  end
  if #ui.model.actions == 0 then
    return nil
  end
  return 1
end

M.render = function(ui)
  if not (ui.buf and vim.api.nvim_buf_is_valid(ui.buf)) then
    return
  end

  ui.selected = next_selected(ui)

  local indicator = ('(%d/%d)'):format(ui.selected or 0, #ui.model.actions)
  local content_width = math.max(ui.content_width or 30, vim.fn.strdisplaywidth(indicator), 30)

  local lines = {}
  local line_meta = {}
  local action_line_by_idx = {}
  local action_idx = 0

  for _, row in ipairs(ui.model.rows) do
    local line_text = row.text
    local label_start_col = nil
    local label_end_col = nil
    if row.kind == 'separator' then
      line_text, label_start_col, label_end_col = bordered_header(line_text, content_width)
    else
      line_text = pad_right(line_text, content_width)
    end
    local padded = ' ' .. line_text .. ' '
    table.insert(lines, padded)

    local line_no = #lines
    if row.kind == 'action' then
      action_idx = action_idx + 1
      action_line_by_idx[action_idx] = line_no
      line_meta[line_no] = { kind = 'action', action_idx = action_idx }
    else
      line_meta[line_no] = {
        kind = 'separator',
        label_start_col = (label_start_col or 0) + 1, -- account for left padding space
        label_end_col = (label_end_col or 0) + 1,
      }
    end
  end

  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, lines)
  vim.bo[ui.buf].modifiable = false

  local ns = ui.ns
  vim.api.nvim_buf_clear_namespace(ui.buf, ns, 0, -1)
  local separator_hl = ui.border and ui.border.highlight or 'FloatBorder'
  if separator_hl == '' or separator_hl == nil then
    separator_hl = 'FloatBorder'
  end

  for line_no, meta in pairs(line_meta) do
    if meta.kind == 'separator' then
      vim.api.nvim_buf_add_highlight(ui.buf, ns, separator_hl, line_no - 1, 0, -1)
      vim.api.nvim_buf_add_highlight(ui.buf, ns, 'Comment', line_no - 1, meta.label_start_col, meta.label_end_col)
    end
  end

  ui.action_line_by_idx = action_line_by_idx
  ui.line_meta = line_meta

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    local cfg = vim.api.nvim_win_get_config(ui.win)
    cfg.footer = indicator
    cfg.footer_pos = 'right'
    vim.api.nvim_win_set_config(ui.win, cfg)
  end

  if ui.selected and ui.action_line_by_idx[ui.selected] and ui.win and vim.api.nvim_win_is_valid(ui.win) then
    pcall(vim.api.nvim_win_set_cursor, ui.win, { ui.action_line_by_idx[ui.selected], 0 })
  end
end

return M
