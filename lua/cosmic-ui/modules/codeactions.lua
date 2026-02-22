local config = require('cosmic-ui.config')
local utils = require('cosmic-ui.utils')
local M = {}

local function can_run(method_name)
  if not config.is_setup() then
    config.warn_not_setup(method_name)
    return false
  end

  if not config.module_enabled('codeactions') then
    config.warn_module_disabled('codeactions')
    return false
  end

  return true
end

M.open = function(opts)
  if not can_run('codeactions.open(...)') then
    return
  end

  return require('cosmic-ui.code-action').code_actions(opts)
end

M.range = function(opts)
  if not can_run('codeactions.range(...)') then
    return
  end

  local bufnr = 0
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
  opts = utils.merge({
    range = {
      start = { start_pos[1], start_pos[2] },
      ['end'] = { end_pos[1], end_pos[2] },
    },
  }, opts or {})

  return require('cosmic-ui.code-action').code_actions(opts)
end

return M
