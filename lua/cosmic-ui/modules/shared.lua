local config = require('cosmic-ui.config')

local M = {}

M.can_run = function(module_name, method_name)
  if not config.is_setup() then
    config.warn_not_setup(method_name)
    return false
  end

  if not config.module_enabled(module_name) then
    config.warn_module_disabled(module_name)
    return false
  end

  return true
end

return M
