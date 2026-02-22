local M = {}

local defaults = {
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
  codeactions = {
    min_width = nil,
    border = {
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    },
  },
  formatters = {},
}

local known_top_level_keys = {
  notify_title = true,
  rename = true,
  codeactions = true,
  formatters = true,
}

local state = {
  is_setup = false,
  user_opts = {},
  merged_opts = {
    notify_title = defaults.notify_title,
  },
}

local function merge(...)
  return vim.tbl_deep_extend('force', ...)
end

local function warn_once(msg)
  vim.notify_once(msg, vim.log.levels.WARN, {
    title = defaults.notify_title,
  })
end

local function validate(user_opts)
  for key, value in pairs(user_opts) do
    if not known_top_level_keys[key] then
      warn_once(('Unknown cosmic-ui setup key `%s`; ignoring it.'):format(key))
    elseif key ~= 'notify_title' and type(value) ~= 'table' then
      warn_once(('cosmic-ui setup key `%s` must be a table; ignoring it.'):format(key))
    end
  end
end

M.setup = function(user_opts)
  if type(user_opts) ~= 'table' then
    user_opts = {}
  end

  validate(user_opts)

  state.user_opts = vim.deepcopy(user_opts)
  state.merged_opts = {
    notify_title = user_opts.notify_title or defaults.notify_title,
  }

  for module_name, module_defaults in pairs({
    rename = defaults.rename,
    codeactions = defaults.codeactions,
    formatters = defaults.formatters,
  }) do
    local module_user_opts = user_opts[module_name]
    if type(module_user_opts) == 'table' then
      state.merged_opts[module_name] = merge(module_defaults, module_user_opts)
    else
      state.merged_opts[module_name] = nil
    end
  end

  state.is_setup = true
end

M.is_setup = function()
  return state.is_setup
end

M.get = function()
  return state.merged_opts
end

M.module_enabled = function(module_name)
  local module_opts = state.user_opts[module_name]
  return type(module_opts) == 'table' and module_opts.enabled ~= false
end

M.module_opts = function(module_name)
  return state.merged_opts[module_name]
end

M.warn_not_setup = function(method_name)
  warn_once(
    ('cosmic-ui is not set up. Call require("cosmic-ui").setup({...}) before using CosmicUI.%s'):format(
      method_name
    )
  )
end

M.warn_module_disabled = function(module_name)
  warn_once(('cosmic-ui module `%s` is disabled in setup config.'):format(module_name))
end

return M
