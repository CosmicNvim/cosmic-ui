if vim.fn.has("nvim-0.6") ~= 1 then
  error("Sorry this plugin only supports Neovim version > v0.6")
  return
end

if vim.g.loaded_cosmic_ui then
  return
end

vim.g.loaded_cosmic_ui = 1
