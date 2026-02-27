local M = {}
local config = require('cosmic-ui.config')

M.merge = function(...)
  return vim.tbl_deep_extend('force', ...)
end

M.get_relative_path = function(file_path)
  local plenary_path = require('plenary.path')
  local parsed_path, _ = file_path:gsub('file://', '')
  local path = plenary_path:new(parsed_path)
  local relative_path = path:make_relative(vim.fn.getcwd())
  return './' .. relative_path
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
    -- regular vim.notify can't take tables of strings
    local tmp_list = msg
    msg = ''
    for k, v in pairs(tmp_list) do
      msg = msg .. v
      if k < #tmp_list then
        msg = msg .. '\n'
      end
    end
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
