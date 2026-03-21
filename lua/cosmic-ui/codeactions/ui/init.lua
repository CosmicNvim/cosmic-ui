local utils = require('cosmic-ui.utils')
local panel = require('cosmic-ui.ui.panel')
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
  local footer = {
    { key = 'Enter', text = 'apply' },
    { key = 'Esc', text = 'close' },
  }

  if #built.actions == 0 then
    footer = {
      { key = 'Esc', text = 'close' },
    }
  end

  return panel.prepare({
    rows = built.rows,
    footer = footer,
    selected = (#built.actions > 0) and 1 or nil,
  })
end

local function submit_action(action)
  local client = action.client
  local command = action.command

  if not client then
    logger:warn('Code action client is no longer available')
    return
  end

  if not command.edit and transform.supports_code_action_resolve(client) then
    client:request('codeAction/resolve', command, function(resolved_err, resolved_action)
      if resolved_err then
        local code = resolved_err.code or 'unknown'
        local msg = resolved_err.message or vim.inspect(resolved_err)
        logger:error(code .. ': ' .. msg)
        return
      end

      if resolved_action then
        transform.execute_action(transform.transform_action(resolved_action), client)
      else
        transform.execute_action(transform.transform_action(command), client)
      end
    end)
    return
  end

  transform.execute_action(transform.transform_action(command), client)
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
    existing.model = built
    existing.panel = build_panel_model(built)
    existing.min_width = math.max(existing.min_width or 30, user_opts.min_width or 30, built.min_width or 30)
    existing.user_opts = user_opts
    existing.request_state = request_state
    existing.border = user_opts.border or existing.border
    existing.origin_win = origin_win
    if existing.selected and existing.selected > #built.actions then
      existing.selected = nil
    end
    render.render(existing)
    return
  end

  local border = user_opts.border or {}
  local border_style = border.style or vim.o.winborder
  if border_style == '' then
    border_style = nil
  end

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
    width = math.max((user_opts.min_width or built.min_width or 30) + 2, 32),
    height = 1,
    border = border_style,
    title = border.title,
    title_pos = border.title_align,
  })
  if not win then
    window.safe_delete_buf(buf, { force = true })
    return
  end

  vim.wo[win].cursorline = true
  vim.wo[win].cursorlineopt = 'line'
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false

  local winhl = {}
  if border.highlight then
    table.insert(winhl, 'FloatBorder:' .. border.highlight)
  end
  if border.title_hl then
    table.insert(winhl, 'FloatTitle:' .. border.title_hl)
  end
  if border.bottom_hl then
    table.insert(winhl, 'FloatFooter:' .. border.bottom_hl)
  end
  table.insert(winhl, 'CursorLine:Visual')
  if #winhl > 0 then
    vim.wo[win].winhl = table.concat(winhl, ',')
  end

  local ui = {
    buf = buf,
    win = win,
    row = 1,
    col = 0,
    model = built,
    panel = build_panel_model(built),
    selected = (#built.actions > 0) and 1 or nil,
    min_width = math.max(user_opts.min_width or 30, built.min_width or 30),
    user_opts = user_opts,
    request_state = request_state,
    border = border,
    origin_win = origin_win,
    ns = lifecycle.ensure_namespace('cosmic-ui-codeactions'),
  }

  lifecycle.attach_close_autocmds(ui, close_current)
  lifecycle.set_ui(ui)

  local handlers = {
    submit_action = submit_action,
  }

  local deps = {
    close_fn = close_current,
    dismiss_fn = dismiss_current,
    render_fn = render.render,
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
