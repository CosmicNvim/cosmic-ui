local shared = require('cosmic-ui.modules.shared')
local M = {}

local function can_run(method_name)
  return shared.can_run('formatters', method_name)
end

M.open = function(opts)
  if not can_run('formatters.open(...)') then
    return
  end

  return require('cosmic-ui.formatters').open(opts)
end

M.toggle = function(opts)
  if not can_run('formatters.toggle(...)') then
    return
  end

  return require('cosmic-ui.formatters').toggle(opts)
end

M.enable = function(opts)
  if not can_run('formatters.enable(...)') then
    return
  end

  return require('cosmic-ui.formatters').enable(opts)
end

M.disable = function(opts)
  if not can_run('formatters.disable(...)') then
    return
  end

  return require('cosmic-ui.formatters').disable(opts)
end

M.toggle_item = function(opts)
  if not can_run('formatters.toggle_item(...)') then
    return
  end

  return require('cosmic-ui.formatters').toggle_item(opts)
end

M.enable_item = function(opts)
  if not can_run('formatters.enable_item(...)') then
    return
  end

  return require('cosmic-ui.formatters').enable_item(opts)
end

M.disable_item = function(opts)
  if not can_run('formatters.disable_item(...)') then
    return
  end

  return require('cosmic-ui.formatters').disable_item(opts)
end

M.is_item_enabled = function(opts)
  if not can_run('formatters.is_item_enabled(...)') then
    return
  end

  return require('cosmic-ui.formatters').is_item_enabled(opts)
end

M.reset = function(opts)
  if not can_run('formatters.reset(...)') then
    return
  end

  return require('cosmic-ui.formatters').reset(opts)
end

M.is_enabled = function(opts)
  if not can_run('formatters.is_enabled(...)') then
    return
  end

  return require('cosmic-ui.formatters').is_enabled(opts)
end

M.status = function(opts)
  if not can_run('formatters.status(...)') then
    return
  end

  return require('cosmic-ui.formatters').status(opts)
end

M.format = function(opts)
  if not can_run('formatters.format(...)') then
    return
  end

  return require('cosmic-ui.formatters').format(opts)
end

M.format_async = function(opts)
  if not can_run('formatters.format_async(...)') then
    return
  end

  return require('cosmic-ui.formatters').format_async(opts)
end

return M
