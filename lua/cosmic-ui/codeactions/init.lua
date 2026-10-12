local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local guard = require('cosmic-ui.guard')
local request = require('cosmic-ui.codeactions.request')
local ui = require('cosmic-ui.codeactions.ui')
local logger = utils.Logger

local M = {}

local function run_code_actions(opts)
  local bufnr = 0
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    logger:warn('No LSP clients with code actions attached')
    return
  end

  local user_opts = config.module_opts('codeactions') or {}

  request.collect({
    bufnr = bufnr,
    clients = clients,
    user_opts = opts or {},
    on_complete = function(results_lsp)
      ui.open(results_lsp, user_opts)
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
    local range
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' then
      range = utils.range_from_selection(0, mode)
    else
      range = {
        start = vim.api.nvim_buf_get_mark(0, '<'),
        ['end'] = vim.api.nvim_buf_get_mark(0, '>'),
      }
    end
    opts = utils.merge({ range = range }, opts)
  end

  return run_code_actions(opts)
end

return M
