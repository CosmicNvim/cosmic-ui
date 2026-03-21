local constants = require('cosmic-ui.ui.constants')

local M = {}

function M.group_for_state(state)
  return constants.state_highlights[state] or constants.state_highlights.info
end

function M.ensure()
  for name, link in pairs(constants.highlight_links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

return M
