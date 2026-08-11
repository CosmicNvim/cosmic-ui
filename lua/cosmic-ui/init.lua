local config = require('cosmic-ui.config')

local module_map = {
  rename = 'cosmic-ui.rename',
  codeactions = 'cosmic-ui.codeactions',
  formatters = 'cosmic-ui.formatters',
}

local M = {}

M.setup = function(user_opts)
  config.setup(user_opts)
end

M.is_setup = function()
  return config.is_setup()
end

setmetatable(M, {
  __index = function(_, key)
    local module_path = module_map[key]
    if not module_path then
      return nil
    end

    return require(module_path)
  end,
})

return M
