local utils = require('cosmic-ui.utils')
local M = {}

local default_user_opts = {
  notify_title = 'CosmicUI',
  rename = {
    border = {
      highlight = 'FloatBorder',
      title = 'Rename',
      title_align = 'left',
      title_hl = 'FloatBorder',
    },
    prompt = '> ',
    prompt_hl = 'Comment',
  },
  code_actions = {
    min_width = nil,
    border = {
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    },
  },
}

_G.CosmicUI_user_opts = {}

M.setup = function(user_opts)
  -- get parsed user opts
  _G.CosmicUI_user_opts = utils.merge(default_user_opts, user_opts or {})
  user_opts = _G.CosmicUI_user_opts
end

M.rename = function(popup_opts, opts)
  return require('cosmic-ui.rename')(popup_opts, opts)
end

M.code_actions = function(opts)
  require('cosmic-ui.code-action').code_actions(opts)
end

M.range_code_actions = function(opts)
  local bufnr = 0
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
  opts = utils.merge({
    range = {
      start = { start_pos[1], start_pos[2] },
      ['end'] = { end_pos[1], end_pos[2] },
    },
  }, opts or {})
  M.code_actions(opts)
end

return M
