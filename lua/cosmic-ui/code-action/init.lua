local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local request = require('cosmic-ui.code-action.request')
local menu = require('cosmic-ui.code-action.menu')
local logger = utils.Logger

local M = {}

M.code_actions = function(opts)
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

return M
