local window = require('cosmic-ui.window')
local shared_lifecycle = require('cosmic-ui.ui.lifecycle')

return shared_lifecycle.new({
  namespace = 'cosmic-ui-formatters',
  augroup_prefix = 'cosmic_ui_formatters_',
  before_close = function(_, ui)
    window.restore_cursor(ui.cursor_state)
  end,
})
