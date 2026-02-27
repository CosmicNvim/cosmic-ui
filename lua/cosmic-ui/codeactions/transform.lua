local M = {}

local function fix_zero_version(workspace_edit)
  if workspace_edit and workspace_edit.documentChanges then
    for _, change in pairs(workspace_edit.documentChanges) do
      local text_document = change.textDocument
      if text_document and text_document.version and text_document.version == 0 then
        text_document.version = nil
      end
    end
  end
  return workspace_edit
end

M.transform_action = function(action)
  local command = (action.command and action.command.command) or action.command
  if not (command == 'java.apply.workspaceEdit') then
    return action
  end
  local arguments = (action.command and action.command.arguments) or action.arguments
  action.edit = fix_zero_version(arguments[1])
  return action
end

M.execute_action = function(action, client)
  if action.edit or type(action.command) == 'table' then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    if type(action.command) == 'table' then
      client:exec_cmd(action.command)
    end
  else
    client:exec_cmd(action)
  end
end

M.supports_code_action_resolve = function(client)
  if not client then
    return false
  end

  if type(client.supports_method) == 'function' and client:supports_method('codeAction/resolve') then
    return true
  end

  local server_capabilities = client.server_capabilities or {}
  local code_action_provider = server_capabilities.codeActionProvider or server_capabilities.codeAction

  return type(code_action_provider) == 'table'
      and (code_action_provider.resolveProvider or code_action_provider.resolve_provider)
end

return M
