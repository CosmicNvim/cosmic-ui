local M = {}

local function border_extent(border)
  if border == nil or border == '' then
    return 0
  end

  return 2
end

M.create_scratch_buf = function(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    return nil
  end

  vim.bo[buf].bufhidden = opts.bufhidden or 'wipe'
  vim.bo[buf].modifiable = opts.modifiable == true

  if type(opts.filetype) == 'string' and opts.filetype ~= '' then
    vim.bo[buf].filetype = opts.filetype
  end

  return buf
end

M.fit_float_size = function(width, height, opts)
  opts = opts or {}
  local border = border_extent(opts.border)
  local available_width = math.max(1, vim.o.columns - border)
  local available_height = math.max(1, vim.o.lines - vim.o.cmdheight - border)
  local max_width = opts.max_width or math.floor(available_width * (opts.width_ratio or 1))
  local max_height = opts.max_height or math.floor(available_height * (opts.height_ratio or 1))

  max_width = math.max(1, math.min(max_width, available_width))
  max_height = math.max(1, math.min(max_height, available_height))

  return math.max(1, math.min(width, max_width)), math.max(1, math.min(height, max_height))
end

M.centered_float_config = function(width, height, opts)
  opts = opts or {}
  local clamped_width, clamped_height = M.fit_float_size(width, height, opts)
  local border = border_extent(opts.border)
  local usable_height = math.max(1, vim.o.lines - vim.o.cmdheight)
  local row = math.max(0, math.floor((usable_height - clamped_height - border) / 2))
  local col = math.max(0, math.floor((vim.o.columns - clamped_width - border) / 2))

  return {
    width = clamped_width,
    height = clamped_height,
    row = row,
    col = col,
  }
end

M.resolve_border = function(style)
  if style == nil then
    style = vim.o.winborder
  end
  if style == '' then
    return nil
  end
  return style
end

M.apply_panel_window_options = function(win, opts)
  opts = opts or {}
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false
  if opts.cursorline then
    vim.wo[win].cursorline = true
    vim.wo[win].cursorlineopt = 'line'
  end
end

M.apply_border_winhl = function(win, border, extra)
  border = border or {}
  local winhl = {}
  if border.highlight then
    table.insert(winhl, 'FloatBorder:' .. border.highlight)
  end
  if border.title_hl then
    table.insert(winhl, 'FloatTitle:' .. border.title_hl)
  end
  if border.bottom_hl then
    table.insert(winhl, 'FloatFooter:' .. border.bottom_hl)
  end
  for _, entry in ipairs(extra or {}) do
    table.insert(winhl, entry)
  end
  if #winhl > 0 then
    vim.wo[win].winhl = table.concat(winhl, ',')
  end
end

M.open_float = function(buf, config)
  config = vim.tbl_extend('force', {
    relative = 'editor',
    style = 'minimal',
  }, config or {})
  return vim.api.nvim_open_win(buf, true, config)
end

M.set_float_config = function(win, config)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  vim.api.nvim_win_set_config(win, config)
end

M.restore_focus = function(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

M.safe_close_win = function(win)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

M.safe_delete_buf = function(buf, opts)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, opts or { force = true })
  end
end

M.hide_cursor_with_group = function(group)
  local state = {
    prev_guicursor = vim.o.guicursor,
    overridden = false,
  }

  pcall(function()
    local base = state.prev_guicursor
    if base == '' then
      base = 'a:block'
    end
    vim.o.guicursor = base .. ',a:blinkon0-' .. group .. '/' .. group
    state.overridden = true
  end)

  return state
end

M.restore_cursor = function(state)
  if not (state and state.overridden and state.prev_guicursor) then
    return
  end

  pcall(function()
    vim.o.guicursor = state.prev_guicursor
  end)
end

return M
