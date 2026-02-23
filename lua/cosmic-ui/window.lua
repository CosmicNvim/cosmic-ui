local M = {}

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

M.centered_float_config = function(width, height, opts)
  opts = opts or {}
  local max_width = opts.max_width or math.max(50, math.floor(vim.o.columns * 0.9))
  local max_height = opts.max_height or math.max(14, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8))
  local clamped_width = math.min(width, max_width)
  local clamped_height = math.min(height, max_height)
  local row = math.max(1, math.floor(((vim.o.lines - vim.o.cmdheight) - clamped_height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - clamped_width) / 2))

  return {
    width = clamped_width,
    height = clamped_height,
    row = row,
    col = col,
  }
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
