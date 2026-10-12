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

-- Every request opens in the loading state first, so the most recent loading
-- request is the only one allowed to drive the panel. Late responses from an
-- older request must not replace (or reopen) a newer panel.
M.track_request = function(request_state)
  local ui_state = M.get_state()
  if request_state.status == 'loading' then
    ui_state.latest_request = request_state
  end

  local latest = ui_state.latest_request
  return (latest == nil or latest == request_state) and not M.is_request_dismissed(request_state)
end

return M
