local state = require('cosmic-ui.formatters.state')
local constants = require('cosmic-ui.formatters.constants')
local utils = require('cosmic-ui.utils')
local window = require('cosmic-ui.window')
local lifecycle = require('cosmic-ui.formatters.ui.lifecycle')
local rows = require('cosmic-ui.formatters.ui.rows')
local highlights = require('cosmic-ui.formatters.ui.highlights')
local render = require('cosmic-ui.formatters.ui.render')
local input = require('cosmic-ui.formatters.ui.input')
local logger = utils.Logger

local M = {}

M.open = function(opts, handlers)
  opts = opts or {}
  lifecycle.close_current()

  local devicons = rows.get_devicons(logger)
  if not devicons then
    return
  end

  highlights.ensure(lifecycle.get_state(), constants.highlight_links)

  local scope = handlers.resolve_scope(opts.scope)
  if not scope then
    return
  end

  local bufnr = handlers.resolve_bufnr(opts.bufnr)
  if not bufnr then
    return
  end

  local buf = window.create_scratch_buf({
    filetype = 'cosmicui-formatters',
    modifiable = false,
    bufhidden = 'wipe',
  })
  if not buf then
    return
  end

  local border = vim.o.winborder ~= '' and vim.o.winborder or nil
  local win = window.open_float(buf, {
    relative = 'editor',
    style = 'minimal',
    border = border,
    title = 'Toggle Formatters',
    title_pos = 'center',
    row = 2,
    col = 4,
    width = 64,
    height = 14,
  })
  if not win then
    return
  end

  vim.wo[win].cursorline = true
  vim.wo[win].cursorlineopt = 'line'
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false
  vim.wo[win].winhl =
    'FloatTitle:CosmicUiFmtTitle,FloatBorder:CosmicUiFmtSection,CursorLine:CosmicUiFmtCursorLine,Cursor:CosmicUiFmtCursor'

  local ui = {
    scope = scope,
    target_bufnr = bufnr,
    buf = buf,
    win = win,
    selected = nil,
    rows = {},
    cursor_state = window.hide_cursor_with_group('CosmicUiFmtCursor'),
  }

  lifecycle.attach_close_autocmds(ui, lifecycle.close_current)
  lifecycle.set_ui(ui)

  local deps = {
    state = state,
    constants = constants,
    window = window,
    logger = logger,
    rows = rows,
    highlights = highlights,
    ui_state = lifecycle.get_state(),
    close_fn = lifecycle.close_current,
  }

  local function render_fn(target_ui, target_handlers)
    render.render(target_ui, target_handlers, deps)
  end

  input.set_keymaps(ui, handlers, {
    state = state,
    render_fn = render_fn,
    close_fn = lifecycle.close_current,
  })

  render_fn(ui, handlers)
end

M.close = lifecycle.close_current

return M
