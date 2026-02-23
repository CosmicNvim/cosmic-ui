local logger = require('cosmic-ui.utils').Logger

return function(err, result, ctx)
  local utils = require('cosmic-ui.utils')

  if err then
    local method = (ctx and ctx.method) or 'textDocument/rename'
    local err_msg = err.message or vim.inspect(err)
    logger:error(("Error running LSP query '%s': %s"):format(method, err_msg))
    return
  end

  if not result then
    return
  end

  local new_word = ''
  if result.changes then
    local msg = {}
    for f, c in pairs(result.changes) do
      local first_change = c and c[1]
      if first_change and first_change.newText then
        new_word = first_change.newText
      end
      table.insert(msg, ('%d changes -> %s'):format(#c, utils.get_relative_path(f)))
    end
    local currName = vim.fn.expand('<cword>')
    logger:log(msg, { title = ('Rename: %s -> %s'):format(currName, new_word) })
  end

  local client = vim.lsp.get_clients({ id = ctx.client_id })[1]
  local offset_encoding = client and client.offset_encoding or 'utf-16'
  vim.lsp.util.apply_workspace_edit(result, offset_encoding)
end
