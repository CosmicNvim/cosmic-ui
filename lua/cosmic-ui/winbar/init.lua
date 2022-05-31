local augroup_name = 'CosmicUIWinbar'
local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
local user_opts = _G.CosmicUI_user_opts
local utils = require('cosmic-ui.utils')

local function get_diagnostic_count(diag_type)
  return #vim.diagnostic.get(vim.api.nvim_get_current_buf(), { severity = diag_type })
end

local function updateWinbar()
  local active_clients = vim.lsp.get_active_clients()
  if not active_clients or #active_clients <= 0 then
    return
  end

  local msg = user_opts.winbar.msg
  local diag = {
    error = get_diagnostic_count(vim.diagnostic.severity.ERROR),
    warn = get_diagnostic_count(vim.diagnostic.severity.WARN),
    info = get_diagnostic_count(vim.diagnostic.severity.INFO),
    hint = get_diagnostic_count(vim.diagnostic.severity.HINT),
  }

  -- TODO: use devicons to get ft icon
  for severity, count in pairs(diag) do
    if count > 0 then
      msg = msg .. ':\\ ' .. severity .. ':\\ ' .. count
    end
  end

  vim.cmd('setlocal winbar=' .. msg)
end

local events = { 'DiagnosticChanged' }

vim.opt.winbar = user_opts.winbar.msg
vim.api.nvim_create_autocmd(events, {
  pattern = '*',
  callback = updateWinbar,
  group = group,
})
