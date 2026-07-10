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

M.index_of = function(tbl, item)
  for i, val in ipairs(tbl) do
    if val == item then
      return i
    end
  end
end

M.Logger = {}
M.Logger.__index = M.Logger

local function log(type, msg, opts)
  local global_opts = config.get() or {}
  local title = global_opts.notify_title or 'CosmicUI'
  if vim.islist(msg) then
    msg = table.concat(msg, '\n')
  end

  vim.notify(msg, type, {
    title = opts.title or title,
  })
end

function M.Logger:log(msg, opts)
  log(vim.log.levels.INFO, msg, opts or {})
end

function M.Logger:warn(msg, opts)
  log(vim.log.levels.WARN, msg, opts or {})
end

function M.Logger:error(msg, opts)
  log(vim.log.levels.ERROR, msg, opts or {})
end

return M
