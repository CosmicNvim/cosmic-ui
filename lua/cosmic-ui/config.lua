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

local function scalar(expected, validate)
  return {
    expected = expected,
    validate = validate,
  }
end

local function object(fields)
  return {
    expected = 'a table',
    fields = fields,
  }
end

local function is_border_style(value)
  if type(value) == 'string' then
    return true
  end

  if type(value) ~= 'table' or not vim.islist(value) then
    return false
  end

  local count = #value
  if count ~= 1 and count ~= 2 and count ~= 4 and count ~= 8 then
    return false
  end

  for _, entry in ipairs(value) do
    if type(entry) ~= 'string' then
      if type(entry) ~= 'table' or not vim.islist(entry) or (#entry ~= 1 and #entry ~= 2) then
        return false
      end

      if type(entry[1]) ~= 'string' or (entry[2] ~= nil and type(entry[2]) ~= 'string') then
        return false
      end
    end
  end

  return true
end

local string_option = scalar('a string', function(value)
  return type(value) == 'string'
end)

local enabled_option = scalar('a boolean', function(value)
  return type(value) == 'boolean'
end)

local border_fields = {
  highlight = string_option,
  style = scalar('a string or valid border table', is_border_style),
  title = string_option,
  title_align = scalar('one of `left`, `center`, or `right`', function(value)
    return value == 'left' or value == 'center' or value == 'right'
  end),
  title_hl = string_option,
}

local setup_schema = {
  notify_title = string_option,
  rename = object({
    enabled = enabled_option,
    border = object(border_fields),
    prompt = string_option,
    prompt_hl = string_option,
  }),
  codeactions = object({
    enabled = enabled_option,
    min_width = scalar('a positive integer', function(value)
      return type(value) == 'number' and value > 0 and value < math.huge and value == math.floor(value)
    end),
    border = object(vim.tbl_extend('force', border_fields, {
      bottom_hl = string_option,
    })),
  }),
  formatters = object({
    enabled = enabled_option,
  }),
}

local function warn_unknown(path)
  warn_once(('Unknown cosmic-ui setup key `%s`; ignoring it.'):format(path))
end

local function warn_invalid(path, expected)
  warn_once(('cosmic-ui setup key `%s` must be %s; ignoring it.'):format(path, expected))
end

local function sanitize_value(value, path, schema)
  if schema.fields then
    if type(value) ~= 'table' then
      warn_invalid(path, schema.expected)
      return nil
    end

    local sanitized = {}
    for key, nested_value in pairs(value) do
      local nested_schema = schema.fields[key]
      local nested_path = ('%s.%s'):format(path, key)
      if nested_schema then
        local sanitized_value = sanitize_value(nested_value, nested_path, nested_schema)
        if sanitized_value ~= nil then
          sanitized[key] = sanitized_value
        end
      else
        warn_unknown(nested_path)
      end
    end

    return sanitized
  end

  if not schema.validate(value) then
    warn_invalid(path, schema.expected)
    return nil
  end

  return vim.deepcopy(value)
end

local function sanitize(user_opts)
  local sanitized = {}

  for key, value in pairs(user_opts) do
    local schema = setup_schema[key]
    if schema then
      local sanitized_value = sanitize_value(value, key, schema)
      if sanitized_value ~= nil then
        sanitized[key] = sanitized_value
      end
    else
      warn_unknown(key)
    end
  end

  return sanitized
end

M.setup = function(user_opts)
  if type(user_opts) ~= 'table' then
    if user_opts ~= nil then
      warn_invalid('setup', 'a table')
    end
    user_opts = {}
  end

  user_opts = sanitize(user_opts)

  state.user_opts = user_opts
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
    ('cosmic-ui is not set up. Call require("cosmic-ui").setup({...}) before using CosmicUI.%s'):format(method_name)
  )
end

M.warn_module_disabled = function(module_name)
  warn_once(('cosmic-ui module `%s` is disabled in setup config.'):format(module_name))
end

return M
