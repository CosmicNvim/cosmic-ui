vim.opt.runtimepath:prepend(vim.fn.getcwd())
for _, path in ipairs(vim.fn.globpath(vim.fn.stdpath('data') .. '/site/pack/*/start', 'plenary.nvim', false, true)) do
  vim.opt.runtimepath:append(path)
end
for _, path in ipairs(vim.fn.globpath(vim.fn.stdpath('data') .. '/lazy', 'plenary.nvim', false, true)) do
  vim.opt.runtimepath:append(path)
end
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
