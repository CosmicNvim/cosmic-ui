local utils = require('cosmic-ui.utils')
local M = {}

local default_user_opts = {
  lsp_signature = {
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = 'rounded',
    },
  },
  icons = {
    warn = '',
    info = '',
    error = '',
    hint = '',
  },
  diagnostic = {
    underline = true,
    signs = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      header = false,
      source = 'always',
      border = 'rounded',
    },
    virtual_text = {
      spacing = 4,
      source = 'always',
      severity = {
        min = vim.diagnostic.severity.HINT,
      },
    },
  },
  hover = {
    handler = vim.lsp.handlers.hover,
    float = {
      border = 'rounded',
    },
  },
  signature_help = {
    handler = vim.lsp.handlers.signature_help,
    float = {
      border = 'rounded',
    },
  },
}

M.setup = function(user_opts)
  user_opts = utils.merge(default_user_opts, user_opts or {})

  -- set up lsp_signature if enabled
  local ok, lsp_signature = pcall(require, 'lsp_signature')
  if ok and user_opts.signature_help ~= false then
    lsp_signature.setup(user_opts.lsp_signature)
  else
    -- set up signatureHelp
    require('cosmic-ui.signature-help').init(user_opts.signature_help)
  end

  -- set up diagnostics
  require('cosmic-ui.diagnostics').init(user_opts)

  -- set up hover
  require('cosmic-ui.hover').init(user_opts.hover)
end

M.rename = function(popup_opts, opts)
  return require('cosmic-ui.rename')(popup_opts, opts)
end

return M
