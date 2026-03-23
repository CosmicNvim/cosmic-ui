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

M.highlight_links = {
  CosmicUiFmtTitle = 'CosmicUiPanelTitle',
  CosmicUiFmtHeader = 'Identifier',
  CosmicUiFmtSection = 'CosmicUiPanelSection',
  CosmicUiFmtSubtitle = 'CosmicUiPanelSubtitle',
  CosmicUiFmtCursorLine = 'CursorLine',
  CosmicUiFmtCursor = 'Cursor',
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
