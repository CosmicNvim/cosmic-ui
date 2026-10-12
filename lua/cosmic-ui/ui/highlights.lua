local constants = require('cosmic-ui.ui.constants')

local M = {}

function M.group_for_state(state)
  return constants.state_highlights[state] or constants.state_highlights.info
end

-- Extmark replacement for the deprecated nvim_buf_add_highlight(). A negative
-- `col_end` highlights to the end of the line.
function M.add(bufnr, ns, group, line, col_start, col_end)
  local end_row, end_col = line, col_end
  if col_end < 0 then
    end_row, end_col = line + 1, 0
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, line, col_start, {
    end_row = end_row,
    end_col = end_col,
    hl_group = group,
    strict = false,
  })
end

function M.ensure(links)
  for name, link in pairs(links or constants.highlight_links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

return M
