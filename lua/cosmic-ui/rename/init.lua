local ui = require('cosmic-ui.rename.ui')
local guard = require('cosmic-ui.guard')

local M = {}

M.open = function(...)
  if not guard.can_run('rename', 'rename.open(...)') then
    return
  end

  local argc = select('#', ...)
  if argc > 1 then
    error('rename.open: invalid arguments')
  end

  local opts = ...
  if opts ~= nil and type(opts) ~= 'table' then
    error('rename.open: invalid arguments')
  end

  return ui.open(opts)
end

return M
