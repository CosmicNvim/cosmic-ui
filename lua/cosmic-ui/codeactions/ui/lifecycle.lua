local shared_lifecycle = require('cosmic-ui.ui.lifecycle')

local M = shared_lifecycle.new({
  namespace = 'cosmic-ui-codeactions',
  augroup_prefix = 'cosmic_ui_codeactions_',
  before_close = function(ui_state, ui, opts)
    if opts.dismissed == true and ui.request_state and ui.request_state.status == 'loading' then
      ui_state.dismissed_request = ui.request_state
    end
  end,
})

M.is_request_dismissed = function(request_state)
  return request_state ~= nil and M.get_state().dismissed_request == request_state
end

return M
