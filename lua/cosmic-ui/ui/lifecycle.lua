local window = require('cosmic-ui.window')

local M = {}

M.attach_close_autocmds = function(ui, close_fn, augroup_prefix)
  ui.augroup = vim.api.nvim_create_augroup(augroup_prefix .. tostring(ui.buf), { clear = true })

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

M.new = function(opts)
  local lifecycle = {}
  local ui_state = {
    ui = nil,
    ns = nil,
  }

  lifecycle.get_state = function()
    return ui_state
  end

  lifecycle.set_ui = function(ui)
    ui_state.ui = ui
  end

  lifecycle.ensure_namespace = function(name)
    if not ui_state.ns then
      ui_state.ns = vim.api.nvim_create_namespace(name or opts.namespace)
    end
    return ui_state.ns
  end

  lifecycle.close_current = function(close_opts)
    local ui = ui_state.ui
    if not ui then
      return
    end

    if opts.before_close then
      opts.before_close(ui_state, ui, close_opts or {})
    end

    ui_state.ui = nil

    if ui.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, ui.augroup)
    end

    window.safe_close_win(ui.win)
    window.safe_delete_buf(ui.buf, { force = true })
    window.restore_focus(ui.origin_win)
  end

  lifecycle.attach_close_autocmds = function(ui, close_fn)
    M.attach_close_autocmds(ui, close_fn, opts.augroup_prefix)
  end

  return lifecycle
end

return M
