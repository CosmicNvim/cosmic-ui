local M = {}
local config = require('cosmic-ui.config')

M.merge = function(...)
  return vim.tbl_deep_extend('force', ...)
end

M.get_relative_path = function(file_path)
  local path = file_path
  if vim.startswith(path, 'file://') then
    local ok, decoded = pcall(vim.uri_to_fname, path)
    if ok then
      path = decoded
    end
  end

  local absolute_path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  local relative_path = vim.fs.relpath(vim.fn.getcwd(), absolute_path)
  if relative_path then
    return './' .. relative_path
  end

  return absolute_path
end

-- Range of the active charwise/linewise visual selection. The `'<`/`'>` marks
-- are only updated after leaving visual mode, so read the live positions.
M.range_from_selection = function(bufnr, mode)
  local start = vim.fn.getpos('v')
  local finish = vim.fn.getpos('.')
  local start_row, start_col = start[2], start[3]
  local end_row, end_col = finish[2], finish[3]

  if start_row == end_row and end_col < start_col then
    start_col, end_col = end_col, start_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == 'V' then
    start_col = 1
    local line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)[1]
    end_col = #line
  end

  return {
    start = { start_row, start_col - 1 },
    ['end'] = { end_row, end_col - 1 },
  }
end

M.Logger = {}

local function log(type, msg, opts, notify)
  local global_opts = config.get() or {}
  local title = global_opts.notify_title or 'CosmicUI'
  if vim.islist(msg) then
    msg = table.concat(msg, '\n')
  end

  notify = notify or vim.notify
  notify(msg, type, {
    title = opts.title or title,
  })
end

function M.Logger:log(msg, opts)
  log(vim.log.levels.INFO, msg, opts or {})
end

function M.Logger:warn(msg, opts)
  log(vim.log.levels.WARN, msg, opts or {})
end

function M.Logger:warn_once(msg, opts)
  log(vim.log.levels.WARN, msg, opts or {}, vim.notify_once)
end

function M.Logger:error(msg, opts)
  log(vim.log.levels.ERROR, msg, opts or {})
end

return M
