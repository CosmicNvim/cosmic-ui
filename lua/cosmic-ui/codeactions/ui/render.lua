local panel = require('cosmic-ui.ui.panel')
local window = require('cosmic-ui.window')

local M = {}

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

  if
    ui.selected
    and ui.action_line_by_idx
    and ui.action_line_by_idx[ui.selected]
    and ui.win
    and vim.api.nvim_win_is_valid(ui.win)
  then
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
    clamp_size = function(width, height)
      local border = ui.border and ui.border.style
      if border == nil then
        border = vim.o.winborder
      end

      return window.fit_float_size(width, height, {
        width_ratio = 0.9,
        height_ratio = 0.7,
        border = border,
      })
    end,
  })
  local width = prepared.width
  local height = prepared.height
  local lines = prepared.lines
  local highlights = prepared.highlights

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    local cfg = {
      width = width,
      height = height,
      title = ui.border and ui.border.title or nil,
      title_pos = ui.border and ui.border.title_align or nil,
    }

    if ui.placement then
      local border = ui.border and ui.border.style
      if border == nil then
        border = vim.o.winborder
      end

      local placed = window.cursor_float_config(ui.placement, width, height, { border = border })
      cfg.relative = placed.relative
      cfg.anchor = placed.anchor
      cfg.row = placed.row
      cfg.col = placed.col
      cfg.height = placed.height
    end

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
