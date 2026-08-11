local utils = require('cosmic-ui.utils')
local panel = require('cosmic-ui.ui.panel')
local ui_constants = require('cosmic-ui.ui.constants')
local window = require('cosmic-ui.window')
local transform = require('cosmic-ui.codeactions.transform')
local lifecycle = require('cosmic-ui.codeactions.ui.lifecycle')
local model = require('cosmic-ui.codeactions.ui.model')
local render = require('cosmic-ui.codeactions.ui.render')
local input = require('cosmic-ui.codeactions.ui.input')
local logger = utils.Logger

local M = {}

local function close_current()
  lifecycle.close_current({ dismissed = false })
end

local function dismiss_current()
  lifecycle.close_current({ dismissed = true })
end

local function build_panel_model(built)
  return panel.prepare({
    rows = built.rows,
    selected = (#built.actions > 0) and 1 or nil,
  })
end

local function apply_model(ui, built, user_opts, request_state, origin_win)
  local min_width = ui_constants.min_width
  ui.model = built
  ui.panel = build_panel_model(built)
  ui.min_width = math.max(ui.min_width or min_width, user_opts.min_width or min_width, built.min_width or min_width)
  ui.user_opts = user_opts
  ui.request_state = request_state
  ui.border = user_opts.border or ui.border or {}
  ui.origin_win = origin_win
end

local function submit_action(action)
  local client = action.client
  local command = action.command
  local context = action.bufnr and { bufnr = action.bufnr } or nil

  if not client then
    logger:warn('Code action client is no longer available')
    return
  end

  if command.disabled then
    logger:error(command.disabled.reason or 'Code action is disabled')
    return
  end

  local is_command = type(command.title) == 'string' and type(command.command) == 'string'
  if is_command then
    transform.execute_action(transform.transform_action(command), client, context)
    return
  end

  if not (command.edit and command.command) and transform.supports_code_action_resolve(client, action.bufnr) then
    client:request('codeAction/resolve', command, function(resolved_err, resolved_action)
      if resolved_err then
        if command.edit or command.command then
          transform.execute_action(transform.transform_action(command), client, context)
          return
        end

        local code = resolved_err.code or 'unknown'
        local msg = resolved_err.message or vim.inspect(resolved_err)
        logger:error(code .. ': ' .. msg)
        return
      end

      if resolved_action then
        transform.execute_action(transform.transform_action(resolved_action), client, context)
      else
        transform.execute_action(transform.transform_action(command), client, context)
      end
    end, action.bufnr)
    return
  end

  transform.execute_action(transform.transform_action(command), client, context)
end

M.open = function(results_lsp, user_opts)
  if not results_lsp then
    logger:warn('No results from textDocument/codeAction')
    return
  end

  local request_state = nil
  if type(results_lsp) == 'table' and results_lsp.responses then
    request_state = results_lsp
    if lifecycle.is_request_dismissed(request_state) then
      return
    end
  end

  user_opts = user_opts or {}
  local built = model.build(results_lsp)
  local origin_win = vim.api.nvim_get_current_win()
  local existing = lifecycle.get_state().ui

  if existing and vim.api.nvim_buf_is_valid(existing.buf) and vim.api.nvim_win_is_valid(existing.win) then
    apply_model(existing, built, user_opts, request_state, origin_win)
    render.render(existing)
    return
  end

  local border = user_opts.border or {}
  local border_style = window.resolve_border(border.style)
  local min_width = ui_constants.min_width

  local initial_width, initial_height =
    window.fit_float_size(math.max((user_opts.min_width or built.min_width or min_width) + 2, min_width + 2), 1, {
      width_ratio = 0.9,
      height_ratio = 0.7,
      border = border_style,
    })

  local buf = window.create_scratch_buf({
    filetype = 'cosmicui-codeactions',
    modifiable = false,
    bufhidden = 'wipe',
  })
  if not buf then
    return
  end

  local win = window.open_float(buf, {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = initial_width,
    height = initial_height,
    border = border_style,
    title = border.title,
    title_pos = border.title_align,
  })
  if not win then
    window.safe_delete_buf(buf, { force = true })
    return
  end

  window.apply_panel_window_options(win, { cursorline = true })
  window.apply_border_winhl(win, border, { 'CursorLine:Visual' })

  local ui = {
    buf = buf,
    win = win,
    selected = (#built.actions > 0) and 1 or nil,
    border = border,
    ns = lifecycle.ensure_namespace(),
  }
  apply_model(ui, built, user_opts, request_state, origin_win)

  lifecycle.attach_close_autocmds(ui, close_current)
  lifecycle.set_ui(ui)

  local handlers = {
    submit_action = submit_action,
  }

  local deps = {
    close_fn = close_current,
    dismiss_fn = dismiss_current,
    render_fn = render.render,
    update_selection_fn = render.update_selection,
  }

  input.set_keymaps(ui, handlers, deps)
  render.render(ui)

  vim.api.nvim_buf_call(buf, function()
    if vim.fn.mode() ~= 'n' then
      vim.api.nvim_input('<Esc>')
    end
  end)
end

M.close = dismiss_current

return M
