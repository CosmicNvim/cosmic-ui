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

M.ui_padding = {
  x = 1,
  y = 0,
}

M.highlight_links = {
  CosmicUiFmtTitle = 'Title',
  CosmicUiFmtHeader = 'Identifier',
  CosmicUiFmtSection = 'Type',
  CosmicUiFmtCursorLine = 'CursorLine',
  CosmicUiFmtCursor = 'Cursor',
  CosmicUiFmtHintKey = 'Special',
  CosmicUiFmtHintText = 'Comment',
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
