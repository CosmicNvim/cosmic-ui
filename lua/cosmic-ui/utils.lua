local M = {}

M.merge = function(defaults, opts)
  return vim.tbl_deep_extend('force', defaults, opts or {})
end

-- Default backspace has inconsistent behavior, have to make our own (for now)
-- Taken from here:
-- https://github.com/neovim/neovim/issues/14116#issuecomment-976069244
local prompt_backspace = function(prompt)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  if col ~= prompt then
    vim.api.nvim_buf_set_text(0, line - 1, col - 1, line - 1, col, { '' })
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })
  end
end

local map = function(input, lhs, rhs)
  input:map('i', lhs, rhs, { noremap = true }, false)
end

M.default_mappings = function(input)
  local prompt = input.input_props.prompt:len()

  map(input, '<ESC>', function()
    input.input_props.on_close()
  end)

  map(input, '<C-c>', function()
    input.input_props.on_close()
  end)

  map(input, '<BS>', function()
    prompt_backspace(prompt)
  end)
end

return M
