local panel = require('cosmic-ui.ui.panel')

local M = {}

local function clamp_ui_size(width, height)
  local max_width = math.max(36, math.floor(vim.o.columns * 0.9))
  local max_height = math.max(8, math.floor((vim.o.lines - vim.o.cmdheight) * 0.7))
  return math.min(width, max_width), math.min(height, max_height)
end

local function selection_indicator(ui)
  if #ui.model.actions == 0 then
    return nil
  end

  return ('(%d/%d)'):format(ui.selected or 0, #ui.model.actions)
end

local function apply_selection(ui)
  local indicator = selection_indicator(ui)

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    vim.api.nvim_win_set_config(ui.win, {
      footer = indicator,
      footer_pos = indicator and 'right' or nil,
    })
  end

  if ui.selected and ui.action_line_by_idx and ui.action_line_by_idx[ui.selected] and ui.win and vim.api.nvim_win_is_valid(
      ui.win
    ) then
    pcall(vim.api.nvim_win_set_cursor, ui.win, { ui.action_line_by_idx[ui.selected], 0 })
  end
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

M.update_selection = function(ui)
  if not (ui.buf and vim.api.nvim_buf_is_valid(ui.buf)) then
    return
  end

  M.ensure_selection(ui)
  apply_selection(ui)
end

M.render = function(ui)
  if not (ui.buf and vim.api.nvim_buf_is_valid(ui.buf)) then
    return
  end

  M.ensure_selection(ui)

  local prepared = panel.prepare_standard(ui.panel, {
    min_width = ui.min_width or 30,
    clamp_size = clamp_ui_size,
  })
  local width = prepared.width
  local height = prepared.height
  local lines = prepared.lines
  local highlights = prepared.highlights

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    local cfg = vim.api.nvim_win_get_config(ui.win)
    cfg.width = width
    cfg.height = height
    cfg.title = ui.border and ui.border.title or nil
    cfg.title_pos = ui.border and ui.border.title_align or nil
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

  ui.action_line_by_idx = prepared.action_line_by_idx
  M.update_selection(ui)
end

return M
