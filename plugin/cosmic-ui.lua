if vim.fn.has("nvim-0.11") ~= 1 then
  error("Sorry this plugin only supports Neovim version >= v0.11")
  return
end

if vim.g.loaded_cosmic_ui then
  return
end

vim.g.loaded_cosmic_ui = 1
_G.CosmicUI = require('cosmic-ui')
