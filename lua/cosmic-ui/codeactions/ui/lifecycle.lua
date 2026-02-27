local window = require('cosmic-ui.window')

local M = {}

local ui_state = {
  ui = nil,
}

M.get_state = function()
  return ui_state
end

M.set_ui = function(ui)
  ui_state.ui = ui
end

M.close_current = function()
  local ui = ui_state.ui
  if not ui then
    return
  end

  ui_state.ui = nil

  if ui.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, ui.augroup)
  end

  window.safe_close_win(ui.win)
  window.safe_delete_buf(ui.buf, { force = true })
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
