local M = {}

local function do_diagnostic_signs(icons)
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

local function do_legacy_diagnostic_signs(icons)
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

M.init = function(user_opts)
  -- set up LSP signs
  do_diagnostic_signs(user_opts.icons)
  do_legacy_diagnostic_signs(user_opts.icons)

  -- set up vim.diagnostics
  -- vim.diagnostic.config opts
  vim.diagnostic.config(user_opts.diagnostic)
end

return M
