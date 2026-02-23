local shared = require('cosmic-ui.modules.shared')
local M = {}

M.open = function(popup_opts, opts)
  if not shared.can_run('rename', 'rename.open(...)') then
    return
  end

  return require('cosmic-ui.rename')(popup_opts, opts)
end

return M
