local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local guard = require('cosmic-ui.guard')
local request = require('cosmic-ui.codeactions.request')
local menu = require('cosmic-ui.codeactions.menu')
local logger = utils.Logger

local M = {}

local function run_code_actions(opts)
  local bufnr = 0
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    logger:warn('No LSP clients with code actions attached')
    return
  end

  opts = utils.merge({ params = nil, range = nil }, opts or {})
  local user_opts = config.module_opts('codeactions') or {}

  request.collect({
    bufnr = bufnr,
    clients = clients,
    user_opts = opts,
    on_complete = function(results_lsp)
      menu.open(results_lsp, user_opts)
    end,
  })
end

M.open = function(opts)
  if not guard.can_run('codeactions', 'codeactions.open(...)') then
    return
  end

  return run_code_actions(opts)
end

M.range = function(opts)
  if not guard.can_run('codeactions', 'codeactions.range(...)') then
    return
  end

  opts = opts or {}
  if not opts.range and not opts.params then
    local bufnr = 0
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    opts = utils.merge({
      range = {
        start = { start_pos[1], start_pos[2] },
        ['end'] = { end_pos[1], end_pos[2] },
      },
    }, opts)
  end

  return run_code_actions(opts)
end

return M
