local config = require('cosmic-ui.config')
local M = {}

M.open = function(popup_opts, opts)
  if not config.is_setup() then
    config.warn_not_setup('rename.open(...)')
    return
  end

  if not config.module_enabled('rename') then
    config.warn_module_disabled('rename')
    return
  end

  return require('cosmic-ui.rename')(popup_opts, opts)
end

return M
