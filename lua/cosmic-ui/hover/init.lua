local M = {}

M.init = function(opts)
  vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(opts.handler, opts.float)
end

return M
