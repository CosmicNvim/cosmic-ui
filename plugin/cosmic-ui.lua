if vim.fn.has('nvim-0.11') ~= 1 then
  error('Sorry this plugin only supports Neovim version >= v0.11')
  return
end

if vim.g.loaded_cosmic_ui then
  return
end

vim.g.loaded_cosmic_ui = 1
_G.CosmicUI = require('cosmic-ui')

vim.api.nvim_create_user_command('CosmicRename', function()
  require('cosmic-ui').rename.open()
end, {})

vim.api.nvim_create_user_command('CosmicCodeActions', function()
  require('cosmic-ui').codeactions.open()
end, {})

vim.api.nvim_create_user_command('CosmicFormatters', function()
  require('cosmic-ui').formatters.open()
end, {})

vim.api.nvim_create_user_command('CosmicFormat', function()
  require('cosmic-ui').formatters.format()
end, {})
