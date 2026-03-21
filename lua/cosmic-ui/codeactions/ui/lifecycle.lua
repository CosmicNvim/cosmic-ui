local window = require('cosmic-ui.window')

local M = {}

local ui_state = {
  dismissed_request = nil,
  ui = nil,
  ns = nil,
}

M.get_state = function()
  return ui_state
end

M.set_ui = function(ui)
  ui_state.ui = ui
end

M.is_request_dismissed = function(request_state)
  return request_state ~= nil and ui_state.dismissed_request == request_state
end

M.ensure_namespace = function(name)
  if not ui_state.ns then
    ui_state.ns = vim.api.nvim_create_namespace(name or 'cosmic-ui-codeactions')
  end
  return ui_state.ns
end

M.close_current = function(opts)
  local ui = ui_state.ui
  if not ui then
    return
  end

  opts = opts or {}
  if opts.dismissed and ui.request_state and ui.request_state.status == 'loading' then
    ui_state.dismissed_request = ui.request_state
  end

  ui_state.ui = nil

  if ui.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, ui.augroup)
  end

  window.safe_close_win(ui.win)
  window.safe_delete_buf(ui.buf, { force = true })
  window.restore_focus(ui.origin_win)
end

M.attach_close_autocmds = function(ui, close_fn)
  ui.augroup = vim.api.nvim_create_augroup('cosmic_ui_codeactions_' .. tostring(ui.buf), { clear = true })

  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    group = ui.augroup,
    buffer = ui.buf,
    callback = function()
      close_fn()
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = ui.augroup,
    pattern = tostring(ui.win),
    callback = function()
      close_fn()
    end,
  })
end

return M
