local M = {}

local function clamp_ui_size(width, height)
  local max_width = math.max(50, math.floor(vim.o.columns * 0.9))
  local max_height = math.max(14, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8))
  return math.min(width, max_width), math.min(height, max_height)
end

M.ensure_selection = function(ui)
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

M.set_cursor_to_selected = function(ui)
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

M.render = function(ui, handlers, deps)
  if not ui.buf or not vim.api.nvim_buf_is_valid(ui.buf) then
    return
  end

  local devicons = deps.rows.get_devicons(deps.logger)
  if not devicons then
    deps.close_fn()
    return
  end

  local ns = deps.highlights.ensure(deps.ui_state, deps.constants.highlight_links)

  local status = handlers.status_fn({ scope = ui.scope, bufnr = ui.target_bufnr })
  if not status then
    return
  end

  local icons = deps.rows.make_icons(devicons, ui.target_bufnr)
  local rows = deps.rows.build_rows(status, icons, deps.constants.status_icons)

  ui.rows = rows
  M.ensure_selection(ui)

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
  for _, row in ipairs(rows) do
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
  for _ = 1, deps.constants.ui_padding.y do
    table.insert(lines, '')
  end

  local left_pad = string.rep(' ', deps.constants.ui_padding.x)
  for _, line in ipairs(content_lines) do
    table.insert(lines, left_pad .. line)
  end

  for _ = 1, deps.constants.ui_padding.y do
    table.insert(lines, '')
  end

  for _, row in ipairs(rows) do
    row.lnum = row.lnum + deps.constants.ui_padding.y
  end
  ui.header_lnum = ui.header_lnum + deps.constants.ui_padding.y
  ui.footer_lnum = ui.footer_lnum + deps.constants.ui_padding.y

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

  for i, line in ipairs(lines) do
    local display = vim.fn.strdisplaywidth(line)
    if display < width then
      lines[i] = line .. string.rep(' ', width - display)
    end
  end

  local centered = deps.window.centered_float_config(width, height)
  local border = vim.o.winborder ~= '' and vim.o.winborder or nil
  local win_config = {
    relative = 'editor',
    style = 'minimal',
    border = border,
    title = 'Toggle Formatters',
    title_pos = 'center',
    row = centered.row,
    col = centered.col,
    width = centered.width,
    height = centered.height,
  }

  deps.window.set_float_config(ui.win, win_config)

  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, lines)
  vim.bo[ui.buf].modifiable = false
  ui.icons = icons
  deps.highlights.apply(ui.buf, ns, ui, lines)

  M.set_cursor_to_selected(ui)
end

return M
