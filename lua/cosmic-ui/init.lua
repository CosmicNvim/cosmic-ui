local utils = require('cosmic-ui.utils')
local M = {}

local default_border = 'single'
local default_user_opts = {
  border = default_border,
  rename = {
    prompt = '> ',
    popup_opts = {},
  },
  code_actions = {
    popup_opts = {},
  },
}

_G.CosmicUI_user_opts = {}

M.setup = function(user_opts)
  -- get default opts with borders set from user config
  local default_opts = utils.set_border(user_opts.border or default_border, default_user_opts)

  -- get parsed user opts
  _G.CosmicUI_user_opts = utils.merge(default_opts, user_opts or {})
  user_opts = _G.CosmicUI_user_opts
end

M.rename = function(popup_opts, opts)
  return require('cosmic-ui.rename')(popup_opts, opts)
end

M.code_actions = function(opts)
  require('cosmic-ui.code-action').code_actions(opts)
end

M.range_code_actions = function(opts)
  opts = utils.merge({
    params = vim.lsp.util.make_given_range_params(),
  }, opts or {})
  M.code_actions(opts)
end

return M
