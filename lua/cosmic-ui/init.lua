local config = require('cosmic-ui.config')

local module_map = {
  rename = 'cosmic-ui.modules.rename',
  codeactions = 'cosmic-ui.modules.codeactions',
}

local M = {
  _modules = {},
}

M.setup = function(user_opts)
  config.setup(user_opts)
end

M.is_setup = function()
  return config.is_setup()
end

setmetatable(M, {
  __index = function(tbl, key)
    local module_path = module_map[key]
    if not module_path then
      return nil
    end

    local cached = rawget(tbl._modules, key)
    if cached then
      return cached
    end

    local loaded = require(module_path)
    tbl._modules[key] = loaded
    return loaded
  end,
})

return M
