local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local window = require('cosmic-ui.window')

local M = {}
local prompt_ns = vim.api.nvim_create_namespace('cosmic-ui-rename-prompt')

local function assert_table(val)
  return val == nil or type(val) == 'table'
end

local function validate_open_opts(opts)
  if not assert_table(opts) then
    error('rename.open: invalid arguments')
  end

  if not opts then
    return
  end

  local allowed = {
    prompt = true,
    default_value = true,
    on_submit = true,
    window = true,
  }

  for key in pairs(opts) do
    if not allowed[key] then
      error('rename.open: invalid arguments')
    end
  end

  if opts.prompt ~= nil and type(opts.prompt) ~= 'string' then
    error('rename.open: invalid arguments')
  end

  if opts.default_value ~= nil and type(opts.default_value) ~= 'string' then
    error('rename.open: invalid arguments')
  end

  if opts.on_submit ~= nil and type(opts.on_submit) ~= 'function' then
    error('rename.open: invalid arguments')
  end

  if not assert_table(opts.window) then
    error('rename.open: invalid arguments')
  end
end

local function default_submitter(curr_name, target_ctx)
  return function(new_name)
    if not (new_name and #new_name > 0) or new_name == curr_name then
      return
    end

    if not (target_ctx.winid and vim.api.nvim_win_is_valid(target_ctx.winid)) then
      return
    end

    pcall(vim.api.nvim_win_call, target_ctx.winid, function()
      pcall(vim.api.nvim_win_set_cursor, target_ctx.winid, target_ctx.cursor)
      lsp.buf.rename(new_name, { bufnr = target_ctx.bufnr })
    end)
  end
end

M.open = function(opts)
  validate_open_opts(opts)

  opts = opts or {}
  local target_bufnr = vim.api.nvim_get_current_buf()
  local target_winid = vim.api.nvim_get_current_win()
  local target_cursor = vim.api.nvim_win_get_cursor(target_winid)
  local curr_name = vim.fn.expand('<cword>')

  local clients = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/rename' })
  if #clients == 0 then
    utils.Logger:warn('No LSP clients with rename attached')
    return
  end

  local user_opts = config.module_opts('rename') or {}
  local user_border = user_opts.border or {}

  local prompt = opts.prompt or user_opts.prompt or '> '
  local default_value = opts.default_value or curr_name
  local on_submit = opts.on_submit
    or default_submitter(curr_name, {
      bufnr = target_bufnr,
      winid = target_winid,
      cursor = target_cursor,
    })

  local width = math.max(25, #default_value + #prompt + 1)
  local merged_window_opts = utils.merge({
    relative = 'cursor',
    row = 1,
    col = 0,
    width = width,
    height = 1,
    zindex = 50,
    border = {
      style = user_border.style or vim.o.winborder,
      title = user_border.title,
      title_align = user_border.title_align,
      highlight = user_border.highlight,
      title_hl = user_border.title_hl,
    },
  }, opts.window or {})

  local buf = window.create_scratch_buf({
    filetype = 'cosmicui-rename',
    modifiable = true,
    bufhidden = 'wipe',
  })
  if not buf then
    return
  end

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false

  local border = merged_window_opts.border or {}
  local win = window.open_float(buf, {
    relative = merged_window_opts.relative,
    row = merged_window_opts.row,
    col = merged_window_opts.col,
    width = math.max(1, merged_window_opts.width or width),
    height = math.max(1, merged_window_opts.height or 1),
    zindex = merged_window_opts.zindex,
    border = border.style,
    title = border.title,
    title_pos = border.title_align,
  })
  if not win then
    window.safe_delete_buf(buf, { force = true })
    return
  end

  local winhl = {}
  if border.highlight then
    table.insert(winhl, 'FloatBorder:' .. border.highlight)
  end
  if border.title_hl then
    table.insert(winhl, 'FloatTitle:' .. border.title_hl)
  end
  if #winhl > 0 then
    vim.wo[win].winhl = table.concat(winhl, ',')
  end

  local line = prompt .. default_value
  local prompt_len = #prompt
  local prompt_hl = user_opts.prompt_hl or 'Comment'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  vim.api.nvim_buf_clear_namespace(buf, prompt_ns, 0, -1)
  if prompt_len > 0 then
    vim.api.nvim_buf_set_extmark(buf, prompt_ns, 0, 0, {
      end_row = 0,
      end_col = prompt_len,
      hl_group = prompt_hl,
      priority = 300,
    })
  end

  local closed = false
  local submitted = false
  local augroup = vim.api.nvim_create_augroup('cosmic_ui_rename_' .. tostring(buf), { clear = true })

  local function close()
    if closed then
      return
    end
    closed = true

    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    window.safe_close_win(win)
    window.safe_delete_buf(buf, { force = true })
  end

  local function submit(new_name_arg)
    if submitted then
      return
    end
    submitted = true

    local new_name = new_name_arg or vim.api.nvim_get_current_line()
    if vim.startswith(new_name, prompt) then
      new_name = new_name:sub(#prompt + 1)
    end
    close()
    vim.schedule(function()
      on_submit(new_name)
    end)
  end

  local function set_cursor_col(col)
    local ok = pcall(vim.api.nvim_win_set_cursor, win, { 1, col })
    return ok
  end

  local function ensure_cursor_after_prompt()
    if not (win and vim.api.nvim_win_is_valid(win)) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local col = cursor[2]
    local current_line = vim.api.nvim_buf_get_lines(buf, 0, 1, true)[1] or ''
    local min_col = prompt_len
    local max_col = #current_line
    if col < min_col then
      set_cursor_col(min_col)
    elseif col > max_col then
      set_cursor_col(max_col)
    end
  end

  local function backspace()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local col = cursor[2]
    if col <= prompt_len then
      return
    end
    vim.api.nvim_buf_set_text(buf, 0, col - 1, 0, col, { '' })
    set_cursor_col(col - 1)
  end

  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    group = augroup,
    buffer = buf,
    callback = close,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
    pattern = tostring(win),
    callback = close,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = buf,
    callback = ensure_cursor_after_prompt,
  })

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('i', '<BS>', backspace, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<Home>', function()
    set_cursor_col(prompt_len)
  end, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<CR>', submit, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<Esc>', close, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<C-c>', close, map_opts)

  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 1, #line })
  vim.cmd('startinsert!')
end

return M
