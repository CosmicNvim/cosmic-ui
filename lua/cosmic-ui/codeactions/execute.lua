local utils = require('cosmic-ui.utils')
local transform = require('cosmic-ui.codeactions.transform')
local logger = utils.Logger

local M = {}

M.run = function(action, on_executed)
  local client = action.client
  local command = action.command

  if not client then
    logger:warn('Code action client is no longer available')
    return false
  end

  local function after_execute(final_command)
    if on_executed then
      on_executed({
        client = client,
        command = final_command,
        title = action.title or final_command.title,
        kind = action.kind or final_command.kind,
      })
    end
    return true
  end

  if not command.edit and transform.supports_code_action_resolve(client) then
    client:request('codeAction/resolve', command, function(resolved_err, resolved_action)
      if resolved_err then
        local code = resolved_err.code or 'unknown'
        local msg = resolved_err.message or vim.inspect(resolved_err)
        logger:error(code .. ': ' .. msg)
        return
      end

      local final_action = resolved_action or command
      transform.execute_action(transform.transform_action(final_action), client)
      after_execute(final_action)
    end)
    return true
  end

  transform.execute_action(transform.transform_action(command), client)
  return after_execute(command)
end

return M
