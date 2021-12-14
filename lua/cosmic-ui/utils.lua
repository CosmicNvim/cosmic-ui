local M = {}

M.merge = function(...)
  return vim.tbl_deep_extend('force', ...)
end

M.get_relative_path = function(file_path)
  local plenary_path = require('plenary.path')
  local parsed_path, _ = file_path:gsub('file://', '')
  local path = plenary_path:new(parsed_path)
  local relative_path = path:make_relative(vim.fn.getcwd())
  return './' .. relative_path
end

M.index_of = function(tbl, item)
  for i, val in ipairs(tbl) do
    if val == item then
      return i
    end
  end
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
  local prompt = input.input_props.prompt._length

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

M.set_border = function(border, tbl)
  for k, v in pairs(tbl) do
    if k == 'border' then
      tbl[k] = border
    end

    if type(v) == 'table' then
      tbl[k] = M.set_border(border, v)
    end
  end

  return tbl
end

return M
