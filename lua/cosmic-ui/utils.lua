local M = {}

M.merge = function(defaults, opts)
  return vim.tbl_deep_extend('force', defaults, opts or {})
end

M.feedkeys = function(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), 'i', true)
end

M.create_map = function(input, force)
  return function(lhs, rhs)
    if type(rhs) == 'string' then
      local keys = rhs
      rhs = function()
        M.feedkeys(keys)
      end
    end

    input:map('i', lhs, rhs, { noremap = true }, force)
  end
end

M.default_mappings = function(input)
  local map = M.create_map(input, false)
  map('<C-c>', input.input_props.on_close)
  map('<Esc>', input.input_props.on_close)
end

return M
