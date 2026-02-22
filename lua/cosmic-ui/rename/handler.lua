local logger = require('cosmic-ui.utils').Logger

return function(err, result, ctx)
  local utils = require('cosmic-ui.utils')

  if err then
    logger:error(("Error running LSP query '%s': %s"):format(ctx.method, err))
    return
  end

  if not result then
    return
  end

  local new_word = ''
  if result.changes then
    local msg = {}
    for f, c in pairs(result.changes) do
      new_word = c[1].newText
      table.insert(msg, ('%d changes -> %s'):format(#c, utils.get_relative_path(f)))
    end
    local currName = vim.fn.expand('<cword>')
    logger:log(msg, { title = ('Rename: %s -> %s'):format(currName, new_word) })
  end

  local client = vim.lsp.get_clients({ id = ctx.client_id })[1]
  local offset_encoding = client and client.offset_encoding or 'utf-16'
  vim.lsp.util.apply_workspace_edit(result, offset_encoding)
end
