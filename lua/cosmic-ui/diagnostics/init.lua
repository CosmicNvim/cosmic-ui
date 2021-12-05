local icons = require('cosmic-ui.icons')
local utils = require('cosmic-ui.utils')
local M = {}
local function do_diagnostic_signs()
  local signs = {
    Error = icons.error .. ' ',
    Warn = icons.warn .. ' ',
    Hint = icons.hint .. ' ',
    Info = icons.info .. ' ',
  }

  local t = vim.fn.sign_getdefined('DiagnosticSignWarn')
  if vim.tbl_isempty(t) then
    for type, icon in pairs(signs) do
      local hl = 'DiagnosticSign' .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
    end
  end
end

local function do_legacy_diagnostic_signs()
  local signs = {
    Error = icons.error .. ' ',
    Warning = icons.warn .. ' ',
    Hint = icons.hint .. ' ',
    Information = icons.info .. ' ',
  }
  local h = vim.fn.sign_getdefined('LspDiagnosticsSignWarn')
  if vim.tbl_isempty(h) then
    for type, icon in pairs(signs) do
      local hl = 'LspDiagnosticsSign' .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
    end
  end
end

M.init = function(diagnostic_opts)
  -- set up LSP signs
  do_diagnostic_signs()
  do_legacy_diagnostic_signs()

  -- set up vim.diagnostics
  -- vim.diagnostic.config opts
  vim.diagnostic.config(diagnostic_opts)
end

return M
