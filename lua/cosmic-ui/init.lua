local utils = require('cosmic-ui.utils')
local M = {}

local default_border = 'single'
local default_user_opts = {
  border = default_border,
  lsp_signature = {
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = '',
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
      border = '',
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
      border = default_border,
    },
  },
  signature_help = {
    handler = vim.lsp.handlers.signature_help,
    float = {
      border = default_border,
    },
  },
  rename = {
    prompt = '> ',
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

  -- set up lsp_signature if enabled
  local ok, lsp_signature = pcall(require, 'lsp_signature')
  if ok and user_opts.lsp_signature ~= false then
    lsp_signature.setup(user_opts.lsp_signature)
  elseif user_opts.signature_help ~= false then
    -- set up signatureHelp
    require('cosmic-ui.signature-help').init(user_opts.signature_help)
  end

  if user_opts.diagnostic ~= false then
    -- set up diagnostics
    require('cosmic-ui.diagnostics').init(user_opts)
  end

  if user_opts.hover ~= false then
    -- set up hover
    require('cosmic-ui.hover').init(user_opts.hover)
  end
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

M.get_border = function()
  return _G.CosmicUI_user_opts.border
end

return M
