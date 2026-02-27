local ui = require('cosmic-ui.rename.ui')
local guard = require('cosmic-ui.guard')

local M = {}

M.open = function(popup_opts, opts)
  if not guard.can_run('rename', 'rename.open(...)') then
    return
  end

  return ui.open(popup_opts, opts)
end

return M
