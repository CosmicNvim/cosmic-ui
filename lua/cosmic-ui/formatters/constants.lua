local ui_constants = require('cosmic-ui.ui.constants')

local M = {}

M.default_backend_state = {
  lsp = true,
  conform = true,
}

M.status_icons = {
  enabled = '',
  disabled = '󰄱',
  unavailable = '',
}

M.ui_padding = ui_constants.padding

M.panel_size = {
  base_width = 64,
  base_height = 14,
  width_ratio = 0.9,
  height_ratio = 0.8,
}

-- CosmicUiFmtCursorLine and CosmicUiFmtCursor are defined dynamically in
-- formatters.ui.highlights with a computed background, not linked here.
M.highlight_links = {
  CosmicUiFmtTitle = 'CosmicUiPanelTitle',
  CosmicUiFmtHeader = 'Identifier',
  CosmicUiFmtSection = 'CosmicUiPanelSection',
  CosmicUiFmtSubtitle = 'CosmicUiPanelSubtitle',
  CosmicUiFmtEnabled = 'String',
  CosmicUiFmtDisabled = 'Comment',
  CosmicUiFmtUnavailable = 'WarningMsg',
  CosmicUiFmtIcon = 'Function',
}

M.lsp_format_modes = {
  never = true,
  fallback = true,
  prefer = true,
  first = true,
  last = true,
}

return M
