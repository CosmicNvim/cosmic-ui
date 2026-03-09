local transform = require('cosmic-ui.codeactions.transform')
local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

M.execute = function(action, client)
  if not client then
    logger:warn('Code action client is no longer available')
    return false
  end

  if not action.edit and transform.supports_code_action_resolve(client) then
    client:request('codeAction/resolve', action, function(resolved_err, resolved_action)
      if resolved_err then
        local code = resolved_err.code or 'unknown'
        local msg = resolved_err.message or vim.inspect(resolved_err)
        logger:error(code .. ': ' .. msg)
        transform.execute_action(transform.transform_action(action), client)
        return
      end

      local command = resolved_action or action
      transform.execute_action(transform.transform_action(command), client)
    end)
    return true
  end

  transform.execute_action(transform.transform_action(action), client)
  return true
end

return M
